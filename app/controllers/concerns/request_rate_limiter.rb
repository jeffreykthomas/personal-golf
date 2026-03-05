module RequestRateLimiter
  extend ActiveSupport::Concern

  private

  def throttle!(key:, limit:, window:)
    counter_key = "throttle:#{key}"
    count = Rails.cache.increment(counter_key, 1, expires_in: window)
    if count.nil?
      Rails.cache.write(counter_key, 1, expires_in: window)
      count = 1
    end

    return true if count <= limit

    render json: {
      error: "rate_limited",
      retry_after_seconds: window.to_i
    }, status: :too_many_requests
    false
  end
end
