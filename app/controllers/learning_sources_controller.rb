class LearningSourcesController < ApplicationController
  before_action :require_life_mode!
  before_action :set_learning_node
  before_action :set_learning_source, only: [:summarize]

  def create
    @learning_source = @learning_node.learning_sources.new(learning_source_params.except(:uploaded_file))
    uploaded_file = learning_source_params[:uploaded_file]

    if uploaded_file.present?
      @learning_source.source_type = :upload
      @learning_source.title = @learning_source.title.presence || uploaded_file.original_filename
      @learning_source.uploaded_file.attach(uploaded_file)
    else
      @learning_source.source_type = :user_url
    end

    @learning_source.extraction_status = :discovered

    if @learning_source.save
      LearningSourceSummarizationJob.perform_later(@learning_source.id)
      redirect_to learning_path(node_id: @learning_node.id)
    else
      redirect_to learning_path(node_id: @learning_node.id), alert: @learning_source.errors.full_messages.to_sentence
    end
  end

  def summarize
    LearningSourceSummarizationJob.perform_later(@learning_source.id)
    redirect_to learning_path(node_id: @learning_node.id)
  end

  private

  def set_learning_node
    @learning_node = current_user.learning_nodes.find(params[:learning_node_id])
  end

  def set_learning_source
    @learning_source = @learning_node.learning_sources.find(params[:id])
  end

  def learning_source_params
    params.require(:learning_source).permit(:title, :url, :uploaded_file)
  end
end
