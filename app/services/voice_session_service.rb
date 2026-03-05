require "json"
require "net/http"
require "uri"

class VoiceSessionService
  class VoiceNotConfiguredError < StandardError; end

  def initialize(user:, coach_session: nil)
    @user = user
    @coach_session = coach_session
  end

  def issue_signed_url(voice_name: nil, gender: nil)
    ws_base = ENV["COACH_VOICE_WS_URL"].presence
    raise VoiceNotConfiguredError, "COACH_VOICE_WS_URL is not configured" if ws_base.blank?

    expires_at = 5.minutes.from_now
    token = verifier.generate(
      {
        user_id: @user.id,
        coach_session_id: @coach_session&.id,
        exp: expires_at.to_i
      }
    )

    query = {
      token: token,
      sessionId: @coach_session&.id,
      voiceName: voice_name,
      gender: gender
    }.compact.to_query

    {
      signed_url: "#{ws_base}?#{query}",
      expires_at: expires_at.iso8601,
      voice_id: ENV["COACH_VOICE_ID"].presence || "default"
    }
  end

  def transcribe(audio_base64:, mime_type: "audio/webm")
    endpoint = ENV["COACH_VOICE_TRANSCRIBE_ENDPOINT"].presence
    raise VoiceNotConfiguredError, "COACH_VOICE_TRANSCRIBE_ENDPOINT is not configured" if endpoint.blank?

    post_json(
      endpoint: endpoint,
      payload: {
        audio: audio_base64,
        mimeType: mime_type,
        userId: @user.id,
        coachSessionId: @coach_session&.id
      }
    )
  end

  def synthesize(text:)
    endpoint = ENV["COACH_VOICE_SYNTHESIZE_ENDPOINT"].presence
    raise VoiceNotConfiguredError, "COACH_VOICE_SYNTHESIZE_ENDPOINT is not configured" if endpoint.blank?

    post_json(
      endpoint: endpoint,
      payload: {
        text: text,
        userId: @user.id,
        coachSessionId: @coach_session&.id
      }
    )
  end

  private

  def verifier
    Rails.application.message_verifier(:coach_voice_session)
  end

  def post_json(endpoint:, payload:)
    uri = URI(endpoint)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 5
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri.request_uri, {
      "Content-Type" => "application/json",
      "Authorization" => bearer_header
    }.compact)
    request.body = payload.to_json

    response = http.request(request)
    raise VoiceNotConfiguredError, "voice endpoint failed with #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end

  def bearer_header
    token = ENV["COACH_VOICE_SERVICE_TOKEN"].presence
    token.present? ? "Bearer #{token}" : nil
  end
end
