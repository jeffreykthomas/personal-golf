class LearningGraphController < ApplicationController
  before_action :require_life_mode!

  def show
    respond_to do |format|
      format.html do
        @graph_payload = serializer.call
        @node_count = @graph_payload[:nodes].size
        @edge_count = @graph_payload[:edges].size
      end

      format.json do
        render json: serializer.call
      end
    end
  end

  private

  def serializer
    @serializer ||= LearningGraphSerializer.new(user: current_user)
  end
end
