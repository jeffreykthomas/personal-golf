class CoachMessagesController < ApplicationController
  include CoachFeature
  include RequestRateLimiter

  before_action :require_coach_feature!
  before_action :set_coach_session

  def create
    return unless throttle!(
      key: "coach_messages:create:user:#{current_user.id}",
      limit: 120,
      window: 1.minute
    )

    request_id = params[:request_id].presence || SecureRandom.uuid
    Rails.logger.info("coach_message request_id=#{request_id} user_id=#{current_user.id} session_id=#{@coach_session.id}")
    existing = @coach_session.coach_messages.assistant.find_by(request_id: request_id)
    if existing
      render json: { message: existing.as_payload, actions: existing.metadata["actions"] || [] }
      return
    end

    user_message = create_user_message!(request_id: request_id)

    broadcast!(Coach::EventContract.stream_started(request_id: request_id, session_id: @coach_session.id))

    bridge_result = ClawBridgeService.new(
      user: current_user,
      coach_session: @coach_session,
      request_id: request_id
    ).respond_to(message: user_message.content, context: merged_context)

    apply_profile_updates!(bridge_result[:profile_updates])
    action_results = execute_actions(bridge_result[:actions])

    stream_assistant_deltas!(request_id: request_id, text: bridge_result[:text].to_s)

    assistant_message = @coach_session.coach_messages.create!(
      role: :assistant,
      modality: :text,
      content: bridge_result[:text].to_s,
      request_id: request_id,
      metadata: {
        request_id: request_id,
        source: bridge_result[:source],
        actions: action_results
      }
    )

    payload = assistant_message.as_payload
    payload[:actions] = action_results

    broadcast!(
      Coach::EventContract.assistant_done(
        request_id: request_id,
        session_id: @coach_session.id,
        message: payload,
        actions: action_results
      )
    )

    render json: {
      message: payload,
      actions: action_results
    }
  rescue StandardError => e
    Rails.logger.error("coach message failed request_id=#{request_id}: #{e.class} #{e.message}")
    broadcast!(
      Coach::EventContract.error(
        request_id: request_id,
        session_id: @coach_session.id,
        code: "coach_message_failed",
        message: "Coach failed to respond. Please try again."
      )
    )
    render json: { error: "coach_message_failed" }, status: :unprocessable_entity
  end

  private

  def set_coach_session
    @coach_session = current_user.coach_sessions.find(params[:coach_session_id])
  end

  def create_user_message!(request_id:)
    @coach_session.coach_messages.create!(
      role: :user,
      modality: normalized_modality,
      content: message_params[:content],
      request_id: request_id,
      metadata: {
        request_id: request_id
      }
    )
  end

  def message_params
    params.require(:coach_message).permit(:content, :modality)
  end

  def normalized_modality
    value = message_params[:modality].to_s
    CoachMessage.modalities.key?(value) ? value : "text"
  end

  def merged_context
    incoming = params[:context]
    incoming_hash = if incoming.is_a?(ActionController::Parameters) || incoming.is_a?(Hash)
      incoming.to_unsafe_h
    else
      {}
    end

    (@coach_session.context_data || {}).merge(incoming_hash)
  end

  def apply_profile_updates!(profile_updates)
    return unless profile_updates.is_a?(Hash) && profile_updates.any?

    normalized = profile_updates.deep_stringify_keys
    coach_profile = current_user.coach_profile || current_user.build_coach_profile
    coach_profile.merge_facts!(normalized)

    user_updates = {}
    user_updates[:skill_level] = normalized["skill_level"] if User.skill_levels.key?(normalized["skill_level"])
    user_updates[:handicap] = normalized["handicap"].to_i if normalized["handicap"].present?
    user_updates[:goals] = normalized["goals"].reject(&:blank?) if normalized["goals"].is_a?(Array)
    user_updates[:name] = normalized["name"] if normalized["name"].present?
    current_user.update!(user_updates) if user_updates.any?
  end

  def execute_actions(actions)
    service = CoachTipActionService.new(user: current_user, coach_session: @coach_session)

    Array(actions).map do |action|
      type = action[:type] || action["type"]
      payload = action[:payload] || action["payload"] || {}

      case type
      when "recommend_tip"
        tip = service.recommend_tip!(payload)
        {
          type: type,
          status: "ok",
          tip: tip_payload(tip)
        }
      when "save_tip"
        tip = service.save_tip!(tip_id: payload["tip_id"] || payload[:tip_id])
        {
          type: type,
          status: "ok",
          tip: tip_payload(tip)
        }
      when "dismiss_tip"
        tip = service.dismiss_tip!(tip_id: payload["tip_id"] || payload[:tip_id])
        {
          type: type,
          status: "ok",
          tip: tip_payload(tip)
        }
      when "complete_onboarding"
        {
          type: type,
          status: "ok",
          redirect_path: onboarding_first_tip_path
        }
      else
        {
          type: type,
          status: "ignored"
        }
      end
    rescue CoachTipActionService::TipActionError => e
      {
        type: type,
        status: "error",
        error: e.message
      }
    end
  end

  def stream_assistant_deltas!(request_id:, text:)
    return if text.blank?

    sequence = 0
    text.split(/(\s+)/).each_slice(8) do |tokens|
      chunk = tokens.join
      next if chunk.blank?

      broadcast!(
        Coach::EventContract.assistant_delta(
          request_id: request_id,
          session_id: @coach_session.id,
          delta: chunk,
          sequence: sequence
        )
      )
      sequence += 1
    end
  end

  def tip_payload(tip)
    {
      id: tip.id,
      title: tip.title,
      content: tip.content,
      category_name: tip.category&.name,
      phase: tip.phase,
      saved: current_user.saved?(tip),
      dismissed: current_user.dismissed?(tip)
    }
  end

  def broadcast!(payload)
    CoachSessionChannel.broadcast_to(@coach_session, payload)
  end
end
