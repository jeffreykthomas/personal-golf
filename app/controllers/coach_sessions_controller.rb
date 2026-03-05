class CoachSessionsController < ApplicationController
  include CoachFeature
  include RequestRateLimiter

  before_action :require_coach_feature!
  before_action :set_coach_session, only: [:show, :complete_onboarding, :debrief]

  def create
    return unless throttle!(
      key: "coach_sessions:create:user:#{current_user.id}",
      limit: 30,
      window: 1.minute
    )

    phase = normalized_phase
    context = coach_context_params

    @coach_session = find_or_create_session(phase: phase, context: context)
    seed_onboarding_message!(@coach_session) if @coach_session.onboarding?

    render json: {
      session: session_payload(@coach_session),
      messages: @coach_session.coach_messages.order(:created_at).last(30).map(&:as_payload)
    }
  end

  def show
    render json: {
      session: session_payload(@coach_session),
      messages: @coach_session.coach_messages.order(:created_at).last(50).map(&:as_payload)
    }
  end

  def complete_onboarding
    updates = (current_user.coach_profile&.profile_data || {}).merge(profile_updates_params.to_h)
    apply_profile_updates!(updates)
    @coach_session.mark_completed! unless @coach_session.completed?
    current_user.update!(onboarding_completed: true)

    render json: {
      status: "ok",
      redirect_path: onboarding_first_tip_path
    }
  end

  def debrief
    recent_messages = @coach_session.coach_messages.order(created_at: :desc).limit(12).reverse
    saved_tip_titles = current_user.saved_tip_items.order(created_at: :desc).limit(3).pluck(:title)

    summary = [
      "Debrief summary:",
      "- Messages exchanged: #{recent_messages.count}",
      ("- Recently saved tips: #{saved_tip_titles.join(', ')}" if saved_tip_titles.any?),
      "- Next focus: commit to one shot shape and one target per full swing."
    ].compact.join("\n")

    message = @coach_session.coach_messages.create!(
      role: :assistant,
      modality: :text,
      content: summary,
      metadata: { source: "debrief" }
    )

    render json: { status: "ok", message: message.as_payload }
  end

  private

  def set_coach_session
    @coach_session = current_user.coach_sessions.find(params[:id])
  end

  def find_or_create_session(phase:, context:)
    existing = unless ActiveModel::Type::Boolean.new.cast(params[:force_new])
      current_user.coach_sessions.active.where(phase: phase).recent_first.first
    end

    if existing
      existing.append_context!(context)
      existing
    else
      current_user.coach_sessions.create!(
        phase: phase,
        status: :active,
        context_data: context,
        started_at: Time.current,
        last_activity_at: Time.current
      )
    end
  end

  def normalized_phase
    phase = params[:phase].to_s
    CoachSession.phases.key?(phase) ? phase : "pre_round"
  end

  def coach_context_params
    raw = params[:context]
    return {} unless raw.is_a?(ActionController::Parameters) || raw.is_a?(Hash)

    raw.to_unsafe_h
  end

  def profile_updates_params
    params.fetch(:profile, {}).permit(:name, :skill_level, :handicap, goals: [])
  end

  def apply_profile_updates!(updates)
    normalized = updates.to_h.deep_stringify_keys
    coach_profile = current_user.coach_profile || current_user.build_coach_profile
    coach_profile.merge_facts!(normalized.compact_blank)

    user_updates = {}
    user_updates[:name] = normalized["name"] if normalized["name"].present?
    user_updates[:skill_level] = normalized["skill_level"] if User.skill_levels.key?(normalized["skill_level"])
    user_updates[:handicap] = normalized["handicap"].to_i if normalized["handicap"].present?
    if normalized["goals"].is_a?(Array)
      user_updates[:goals] = normalized["goals"].reject(&:blank?)
    end
    current_user.update!(user_updates) if user_updates.any?
  end

  def seed_onboarding_message!(session)
    return if session.coach_messages.exists?

    session.coach_messages.create!(
      role: :assistant,
      modality: :text,
      content: ClawBridgeService::ONBOARDING_QUESTIONS.first,
      metadata: { source: "system_seed" }
    )
  end

  def session_payload(session)
    {
      id: session.id,
      phase: session.phase,
      status: session.status,
      context_data: session.context_data || {},
      started_at: session.started_at&.iso8601,
      ended_at: session.ended_at&.iso8601,
      last_activity_at: session.last_activity_at&.iso8601
    }
  end
end
