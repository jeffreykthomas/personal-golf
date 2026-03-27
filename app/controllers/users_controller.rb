class UsersController < ApplicationController
  allow_unauthenticated_access only: [:new, :create]
  
  def new
    redirect_to new_session_path, alert: "New account creation is temporarily disabled."
  end

  def create
    redirect_to new_session_path, alert: "New account creation is temporarily disabled."
  end

  private

  def user_params
    params.require(:user).permit(:email_address, :password)
  end
end