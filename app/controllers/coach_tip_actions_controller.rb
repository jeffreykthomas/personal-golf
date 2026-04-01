class CoachTipActionsController < ApplicationController
  include CoachFeature
  include RequestRateLimiter

  before_action :require_coach_feature!
  before_action :set_coach_session

  def recommend
    return unless throttle!(
      key: "coach_tip_actions:recommend:user:#{current_user.id}",
      limit: 40,
      window: 1.minute
    )

    tip = tip_service.recommend_tip!(recommend_tip_params.to_h)
    render json: { status: "ok", tip: tip_payload(tip) }
  rescue CoachTipActionService::TipActionError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def save
    return unless throttle!(
      key: "coach_tip_actions:save:user:#{current_user.id}",
      limit: 80,
      window: 1.minute
    )

    tip = tip_service.save_tip!(tip_id: params[:tip_id])
    render json: { status: "ok", tip: tip_payload(tip) }
  rescue CoachTipActionService::TipActionError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def dismiss
    return unless throttle!(
      key: "coach_tip_actions:dismiss:user:#{current_user.id}",
      limit: 80,
      window: 1.minute
    )

    tip = tip_service.dismiss_tip!(tip_id: params[:tip_id])
    render json: { status: "ok", tip: tip_payload(tip) }
  rescue CoachTipActionService::TipActionError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def set_coach_session
    @coach_session = current_user.coach_sessions.find(params[:coach_session_id])
  end

  def tip_service
    @tip_service ||= CoachTipActionService.new(user: current_user, coach_session: @coach_session)
  end

  def recommend_tip_params
    params.require(:tip).permit(
      :title,
      :content,
      :type,
      :entry_type,
      :source,
      :auto_save,
      :category_id,
      :category_slug,
      :phase,
      :skill_level,
      :course_id,
      :hole_number,
      tags: []
    )
  end

  def tip_payload(tip)
    {
      id: tip.id,
      title: tip.title,
      content: tip.content,
      type: tip.type,
      source: tip.source,
      tags: tip.tags,
      category_name: tip.category&.name,
      phase: tip.phase,
      saved: current_user.saved?(tip),
      dismissed: current_user.dismissed?(tip)
    }
  end
end
