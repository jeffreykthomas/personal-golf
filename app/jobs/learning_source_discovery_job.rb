class LearningSourceDiscoveryJob < ApplicationJob
  queue_as :ai_generation

  def perform(node_id)
    node = LearningNode.find(node_id)
    discovered_sources = LearningSourceDiscoveryService.new(node: node).call
    sources_to_summarize = discovered_sources.select { |source| !source.summarized? }

    sources_to_summarize.each do |source|
      LearningSourceSummarizationService.new(source: source).call
    end

    LearningNodeCompilationService.new(node: node).call
    LearningRebalancingService.new(node: node).call if node.reload.crowded?
  end
end
