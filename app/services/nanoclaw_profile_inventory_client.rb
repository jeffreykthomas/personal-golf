require "json"
require "net/http"
require "uri"

class NanoclawProfileInventoryClient
  class BridgeUnavailableError < StandardError; end

  DEFAULT_URL = "http://127.0.0.1:4317".freeze

  def initialize(user:)
    @user = user
  end

  def fetch
    return nil if auth_token.blank?

    uri = URI.join(base_url, "/v1/profile/inventory")
    uri.query = URI.encode_www_form(userId: @user.id)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 2
    http.read_timeout = 5

    response = http.request(Net::HTTP::Get.new(uri.request_uri, headers))
    return nil unless response.is_a?(Net::HTTPSuccess)

    body = JSON.parse(response.body || "{}")
    body["inventory"].is_a?(Hash) ? body["inventory"] : nil
  rescue JSON::ParserError
    nil
  rescue Timeout::Error, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Net::OpenTimeout, Net::ReadTimeout => e
    Rails.logger.info("NanoClaw profile inventory unavailable user=#{@user.id}: #{e.class}")
    nil
  end

  private

  def base_url
    ENV["NANOCLAW_APP_URL"].presence || ENV["CLAW_SIBLING_URL"].presence || DEFAULT_URL
  end

  def auth_token
    ENV["CLAW_SIBLING_TOKEN"].presence
  end

  def headers
    {
      "Content-Type" => "application/json",
      "Authorization" => "Bearer #{auth_token}"
    }
  end
end
