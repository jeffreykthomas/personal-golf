class LearningQuestionsController < ApplicationController
  before_action :require_life_mode!
  before_action :set_learning_node

  def create
    @learning_question = @learning_node.learning_questions.new(learning_question_params)
    @learning_question.status = :pending

    if @learning_question.save
      LearningQuestionAnsweringService.new(question: @learning_question).call
      redirect_to learning_path(node_id: @learning_node.id, anchor: "learning-questions")
    else
      redirect_to learning_path(node_id: @learning_node.id, anchor: "learning-questions"), alert: @learning_question.errors.full_messages.to_sentence
    end
  end

  private

  def set_learning_node
    @learning_node = current_user.learning_nodes.find(params[:learning_node_id])
  end

  def learning_question_params
    params.require(:learning_question).permit(:question_text)
  end
end
