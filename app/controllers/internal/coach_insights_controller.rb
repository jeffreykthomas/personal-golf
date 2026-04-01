module Internal
  class CoachInsightsController < ApplicationController
    allow_unauthenticated_access only: :create
    skip_forgery_protection

    before_action :require_bridge_auth!
    before_action :set_coach_session

    def create
      if params[:user_id].present? && params[:user_id].to_i != @coach_session.user_id
        render json: { error: "user_session_mismatch" }, status: :unprocessable_entity
        return
      end

      tip = CoachTipActionService.new(
        user: @coach_session.user,
        coach_session: @coach_session
      ).recommend_tip!(
        insight_params.to_h.merge(
          type: "Insight",
          source: "agent",
          auto_save: true
        )
      )

      render json: {
        status: "ok",
        tip: tip_payload(tip)
      }
    rescue CoachTipActionService::TipActionError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    private

    def require_bridge_auth!
      token = ENV["CLAW_SIBLING_TOKEN"].presence
      return if token.blank?
      return if request.authorization == "Bearer #{token}"

      render json: { error: "unauthorized" }, status: :unauthorized
    end

    def set_coach_session
      @coach_session = CoachSession.find(params[:coach_session_id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: "coach_session_not_found" }, status: :not_found
    end

    def insight_params
      params.permit(:user_id, :title, :content, :category_slug, tags: [])
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
        saved: @coach_session.user.saved?(tip),
        dismissed: @coach_session.user.dismissed?(tip)
      }
    end
  end
end
