class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create oauth_create oauth_failure ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_url, alert: "Try again later." }

  def new
  end

  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: "Try another email address or password."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path
  end
  
  def oauth_create
    user = User.from_omniauth(request.env["omniauth.auth"])
    
    if user.persisted?
      start_new_session_for(user)
      
      # Redirect to onboarding if new user hasn't completed it
      if user.onboarding_completed?
        redirect_to after_authentication_url, notice: "Successfully signed in with Google!"
      else
        redirect_to onboarding_skill_level_path, notice: "Welcome to Personal Golf!"
      end
    else
      redirect_to new_session_path, alert: "There was an error signing you in with Google."
    end
  end
  
  def oauth_failure
    redirect_to new_session_path, alert: "Authentication failed: #{params[:message]}"
  end
end
