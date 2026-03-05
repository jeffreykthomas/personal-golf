module CoachFeature
  extend ActiveSupport::Concern

  private

  def coach_feature_enabled?
    return ActiveModel::Type::Boolean.new.cast(ENV["ENABLE_COACH_AGENT"]) if ENV.key?("ENABLE_COACH_AGENT")

    !Rails.env.production?
  end

  def require_coach_feature!
    return if coach_feature_enabled?

    render json: { error: "coach_feature_disabled" }, status: :not_found
  end
end
