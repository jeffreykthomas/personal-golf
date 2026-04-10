class LearningController < ApplicationController
  before_action :require_life_mode!

  def show
    @root_nodes = current_user.learning_nodes.roots
    @selected_node = selected_node || @root_nodes.first || current_user.learning_nodes.order(:title).first
    @new_root_node = current_user.learning_nodes.new
    @new_child_node = current_user.learning_nodes.new(parent: @selected_node)
    @new_source = @selected_node&.learning_sources&.build || LearningSource.new
    @new_question = @selected_node&.learning_questions&.build || LearningQuestion.new
  end

  private

  def selected_node
    return if params[:node_id].blank?

    current_user.learning_nodes.find_by(id: params[:node_id])
  end
end
