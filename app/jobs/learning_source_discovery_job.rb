class LearningSourceDiscoveryJob < ApplicationJob
  queue_as :ai_generation

  def perform(node_id)
    node = LearningNode.find(node_id)

    sources = LearningSourceDiscoveryService.new(node: node).call
    sources.each do |source|
      LearningSourceSummarizationService.new(source: source).call
    end

    LearningNodeCompilationService.new(node: node).call
    LearningRebalancingService.new(node: node).call if node.reload.crowded?
  end
end
