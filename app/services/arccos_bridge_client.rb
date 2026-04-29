require "json"
require "net/http"
require "uri"

# Thin HTTP client for triggering a manual Arccos sync on the nanoclaw-golf bridge.
# The bridge endpoint is fire-and-forget: it returns 202 immediately and runs
# the scrape in the background. We poll ArccosProfile.last_sync_status from
# Rails to observe progress.
class ArccosBridgeClient
  class BridgeUnavailableError < StandardError; end

  def initialize(user:)
    @user = user
  end

  def trigger_sync(force: true)
    raise BridgeUnavailableError, "CLAW_SIBLING_URL not configured" if bridge_url.blank?

    uri = URI.join(bridge_url, "/v1/arccos/sync")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 5
    http.read_timeout = 10

    request = Net::HTTP::Post.new(uri.request_uri, headers)
    request.body = { user_id: @user.id, force: force }.to_json

    response = http.request(request)
    unless response.is_a?(Net::HTTPSuccess)
      raise BridgeUnavailableError, "bridge_returned_#{response.code}:#{response.body.to_s[0, 200]}"
    end

    JSON.parse(response.body || "{}")
  rescue JSON::ParserError
    {}
  rescue Timeout::Error, Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout => e
    raise BridgeUnavailableError, "bridge_unreachable:#{e.class}"
  end

  private

  def bridge_url
    ENV["CLAW_SIBLING_URL"].presence
  end

  def headers
    h = { "Content-Type" => "application/json" }
    token = ENV["CLAW_SIBLING_TOKEN"].presence
    h["Authorization"] = "Bearer #{token}" if token
    h
  end
end
