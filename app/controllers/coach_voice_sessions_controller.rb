class CoachVoiceSessionsController < ApplicationController
  include CoachFeature
  include RequestRateLimiter

  before_action :require_coach_feature!
  before_action :set_coach_session, only: [:signed_url, :transcribe, :synthesize]

  def signed_url
    return unless throttle!(
      key: "coach_voice:signed_url:user:#{current_user.id}",
      limit: 30,
      window: 1.minute
    )

    payload = voice_service.issue_signed_url(
      voice_name: params[:voice_name],
      gender: params[:gender]
    )
    render json: payload
  rescue VoiceSessionService::VoiceNotConfiguredError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def transcribe
    return unless throttle!(
      key: "coach_voice:transcribe:user:#{current_user.id}",
      limit: 30,
      window: 1.minute
    )

    result = voice_service.transcribe(
      audio_base64: params[:audio].to_s,
      mime_type: params[:mime_type].presence || "audio/webm"
    )
    render json: result
  rescue VoiceSessionService::VoiceNotConfiguredError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def synthesize
    return unless throttle!(
      key: "coach_voice:synthesize:user:#{current_user.id}",
      limit: 30,
      window: 1.minute
    )

    result = voice_service.synthesize(text: params[:text].to_s)
    render json: result
  rescue VoiceSessionService::VoiceNotConfiguredError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def set_coach_session
    @coach_session = current_user.coach_sessions.find_by(id: params[:coach_session_id]) if params[:coach_session_id].present?
  end

  def voice_service
    @voice_service ||= VoiceSessionService.new(user: current_user, coach_session: @coach_session)
  end
end
