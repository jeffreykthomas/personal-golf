class CoachSessionChannel < ApplicationCable::Channel
  def subscribed
    @coach_session = current_user.coach_sessions.find_by(id: params[:coach_session_id])
    reject unless @coach_session

    stream_for @coach_session
  end
end
