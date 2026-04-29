class SettingsController < ApplicationController
  def show
    @arccos_profile = ArccosProfile.for(current_user)
    @arccos_rounds_count = current_user.arccos_rounds.count
    @arccos_latest_round_at = current_user.arccos_rounds.maximum(:played_on)
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

  def trigger_arccos_sync
    profile = ArccosProfile.for(current_user)
    profile.save! if profile.new_record?

    if profile.last_sync_status == "running"
      redirect_to settings_path, notice: "Arccos sync already running — check back in a few minutes."
      return
    end

    ArccosBridgeClient.new(user: current_user).trigger_sync(force: true)
    profile.update!(last_sync_status: "running", last_sync_error: nil)

    redirect_to settings_path, notice: "Arccos sync started. This can take 10-20 minutes on the first run."
  rescue ArccosBridgeClient::BridgeUnavailableError => e
    Rails.logger.warn("Arccos bridge unreachable: #{e.message}")
    redirect_to settings_path, alert: "Couldn't reach the agent bridge (#{e.message}). Is nanoclaw-golf running?"
  end

  private

  def settings_params
    params.require(:user).permit(:app_mode)
  end
end
