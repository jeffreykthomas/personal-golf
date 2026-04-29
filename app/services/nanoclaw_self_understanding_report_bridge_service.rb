require "json"
require "net/http"
require "securerandom"
require "uri"

class NanoclawSelfUnderstandingReportBridgeService
  class Error < StandardError; end
  class BridgeUnavailableError < Error; end
  class RequestFailedError < Error; end

  DEFAULT_URL = "http://127.0.0.1:4317".freeze
  RETRYABLE_ERRORS = [
    Timeout::Error,
    Errno::ECONNREFUSED,
    Errno::EHOSTUNREACH,
    Net::OpenTimeout,
    Net::ReadTimeout
  ].freeze

  class << self
    def generate_report(user:, source_digest:, prompt:)
      new.generate_report(user:, source_digest:, prompt:)
    end
  end

  def generate_report(user:, source_digest:, prompt:)
    raise BridgeUnavailableError, "NanoClaw self-understanding report bridge is not configured" unless bridge_enabled?

    response = with_retries(max_attempts: 1) do
      uri = URI.join(base_url, "/v1/report/respond")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 5
      http.read_timeout = 240

      request = Net::HTTP::Post.new(uri.request_uri, request_headers)
      request.body = {
        requestId: SecureRandom.uuid,
        transport: "app",
        userId: user.id,
        sourceDigest: source_digest,
        prompt: prompt
      }.to_json
      http.request(request)
    end

    unless response.is_a?(Net::HTTPSuccess)
      raise RequestFailedError,
            "NanoClaw self-understanding report bridge returned #{response.code}: #{response.body.to_s.first(300)}"
    end

    body = JSON.parse(response.body)
    payload = body["report"]
    return payload if payload.is_a?(Hash)

    raise RequestFailedError, "NanoClaw self-understanding report bridge returned no report payload"
  rescue JSON::ParserError => e
    raise RequestFailedError,
          "NanoClaw self-understanding report bridge returned invalid JSON user=#{user.id}: #{e.message}"
  rescue *RETRYABLE_ERRORS => e
    raise BridgeUnavailableError,
          "NanoClaw self-understanding report bridge unavailable user=#{user.id}: #{e.class} #{e.message}"
  rescue StandardError => e
    raise e if e.is_a?(Error)

    raise RequestFailedError,
          "NanoClaw self-understanding report bridge failed user=#{user.id}: #{e.class} #{e.message}"
  end

  private

  def bridge_enabled?
    auth_token.present?
  end

  def base_url
    ENV["NANOCLAW_APP_URL"].presence || ENV["CLAW_SIBLING_URL"].presence || DEFAULT_URL
  end

  def auth_token
    ENV["CLAW_SIBLING_TOKEN"].to_s.presence || nanoclaw_env_value("CLAW_SIBLING_TOKEN")
  end

  def request_headers
    {
      "Content-Type" => "application/json",
      "Authorization" => "Bearer #{auth_token}"
    }
  end

  def with_retries(max_attempts:)
    attempts = 0

    begin
      attempts += 1
      yield
    rescue *RETRYABLE_ERRORS
      raise if attempts >= max_attempts

      sleep(0.25 * attempts)
      retry
    end
  end

  def nanoclaw_env_value(key)
    env_path = Rails.root.join("nanoclaw-golf", ".env")
    return nil unless env_path.exist?

    File.foreach(env_path) do |line|
      next if line.start_with?("#")

      env_key, env_value = line.split("=", 2)
      next unless env_key == key

      return env_value.to_s.strip.delete_prefix('"').delete_prefix("'").delete_suffix('"').delete_suffix("'").presence
    end

    nil
  rescue StandardError => e
    Rails.logger.warn("NanoClaw self-understanding bridge could not read local env #{env_path}: #{e.class} #{e.message}")
    nil
  end
end
