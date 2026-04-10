class LearningNodeCompilationJob < ApplicationJob
  queue_as :ai_generation

  def perform(node_id)
    node = LearningNode.find(node_id)

    LearningNodeCompilationService.new(node: node).call
    LearningRebalancingService.new(node: node).call if node.reload.crowded?
  end
end
