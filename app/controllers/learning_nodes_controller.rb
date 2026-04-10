class LearningNodesController < ApplicationController
  before_action :require_life_mode!
  before_action :set_learning_node, only: [:update, :discover_sources, :compile, :rebalance]

  def create
    parent = current_user.learning_nodes.find_by(id: learning_node_params[:parent_id])
    @learning_node = current_user.learning_nodes.new(learning_node_params.except(:parent_id))
    @learning_node.parent = parent
    @learning_node.status = :pending_research if @learning_node.draft?

    if @learning_node.save
      LearningSourceDiscoveryJob.perform_later(@learning_node.id)
      redirect_to learning_path(node_id: @learning_node.id)
    else
      redirect_to learning_path(node_id: parent&.id), alert: @learning_node.errors.full_messages.to_sentence
    end
  end

  def update
    if @learning_node.update(learning_node_params.except(:parent_id))
      redirect_to learning_path(node_id: @learning_node.id)
    else
      redirect_to learning_path(node_id: @learning_node.id), alert: @learning_node.errors.full_messages.to_sentence
    end
  end

  def discover_sources
    LearningSourceDiscoveryJob.perform_later(@learning_node.id)
    redirect_to learning_path(node_id: @learning_node.id)
  end

  def compile
    LearningNodeCompilationJob.perform_later(@learning_node.id)
    redirect_to learning_path(node_id: @learning_node.id)
  end

  def rebalance
    LearningRebalancingService.new(node: @learning_node).call
    redirect_to learning_path(node_id: @learning_node.id)
  end

  private

  def set_learning_node
    @learning_node = current_user.learning_nodes.find(params[:id])
  end

  def learning_node_params
    params.require(:learning_node).permit(:title, :summary, :body_markdown, :node_kind, :parent_id)
  end
end
