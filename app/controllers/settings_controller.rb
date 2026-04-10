class SettingsController < ApplicationController
  def show
  end

  def update
    requested_mode = settings_params[:app_mode].to_s

    if User.app_modes.key?(requested_mode)
      current_user.update_column(:app_mode, User.app_modes.fetch(requested_mode)) # rubocop:disable Rails/SkipsModelValidations
      redirect_to settings_path
    else
      current_user.errors.add(:app_mode, "is not included in the list")
      render :show, status: :unprocessable_entity
    end
  end

  private

  def settings_params
    params.require(:user).permit(:app_mode)
  end
end
