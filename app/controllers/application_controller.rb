class ApplicationController < ActionController::Base
  include Authentication
  include CoachFeature
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # Commented out for development - uncomment for production
  # allow_browser versions: :modern

  helper_method :current_user, :user_signed_in?, :coach_feature_enabled?, :coach_context_payload,
                :coach_phase_for_page, :coach_auto_open?, :current_app_mode, :golf_mode?, :life_mode?

  private

  def current_user
    Current.user
  end

  def user_signed_in?
    current_user.present?
  end

  def current_app_mode
    return "golf" unless user_signed_in?

    current_user.app_mode || "golf"
  end

  def golf_mode?
    current_app_mode == "golf"
  end

  def life_mode?
    current_app_mode == "life"
  end

  def coach_context_payload
    payload = {
      controller: controller_name,
      action: action_name,
      path: request.path,
      phase: coach_phase_for_page
    }

    if defined?(@course) && @course.present?
      payload[:course_id] = @course.id
      payload[:course_name] = @course.name
    end

    if defined?(@hole) && @hole.present?
      payload[:hole_number] = @hole.number
      payload[:hole_par] = @hole.par
      payload[:hole_yardage] = @hole.yardage
    end

    if defined?(@coach_context_override) && @coach_context_override.is_a?(Hash)
      payload.merge!(@coach_context_override)
    end

    payload
  end

  def coach_phase_for_page
    return "onboarding" if controller_name == "onboarding"
    return "during_round" if controller_name == "courses" && action_name == "hole"
    return "post_round" if controller_name == "courses" && action_name == "show"

    "pre_round"
  end

  def coach_auto_open?
    coach_phase_for_page == "onboarding"
  end

  def require_life_mode!
    return if life_mode?

    redirect_to tips_path
  end

  # Alias for compatibility
  def authenticate_user!
    require_authentication
  end
end
