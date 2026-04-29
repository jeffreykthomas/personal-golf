class LearningSourceSummarizationJob < ApplicationJob
  queue_as :ai_generation

  def perform(source_id)
    source = LearningSource.find(source_id)

    LearningSourceSummarizationService.new(source: source).call
    LearningNodeCompilationService.new(node: source.learning_node).call
    LearningRebalancingService.new(node: source.learning_node).call if source.learning_node.reload.crowded?
  end
end
