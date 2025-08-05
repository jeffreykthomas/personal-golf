class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # Commented out for development - uncomment for production
  # allow_browser versions: :modern

  helper_method :current_user, :user_signed_in?

  private

  def current_user
    Current.user
  end

  def user_signed_in?
    current_user.present?
  end

  # Alias for compatibility
  def authenticate_user!
    require_authentication
  end
end
