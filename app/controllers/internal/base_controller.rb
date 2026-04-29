module Internal
  class BaseController < ApplicationController
    skip_forgery_protection

    before_action :require_bridge_auth!

    private

    def require_bridge_auth!
      token = ENV["CLAW_SIBLING_TOKEN"].presence
      return if token.blank?

      expected = "Bearer #{token}"
      provided = request.authorization.to_s
      return if provided.bytesize == expected.bytesize &&
                ActiveSupport::SecurityUtils.secure_compare(provided, expected)

      render json: { error: "unauthorized" }, status: :unauthorized
    end
  end
end
