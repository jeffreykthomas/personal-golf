class LearningSourceSummarizationJob < ApplicationJob
  queue_as :ai_generation

  def perform(source_id)
    source = LearningSource.find(source_id)

    LearningSourceSummarizationService.new(source: source).call
    LearningNodeCompilationService.new(node: source.learning_node).call
  end
end
