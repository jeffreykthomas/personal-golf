class LearningMaintenanceJob < ApplicationJob
  queue_as :ai_generation

  def perform(user_ids = nil)
    scope = User.life
    scope = scope.where(id: Array(user_ids)) if user_ids.present?

    scope.find_each do |user|
      user.learning_nodes.find_each do |node|
        node.sync_wikilinks!

        if node.pending_research? && node.learning_sources.none?
          LearningSourceDiscoveryJob.perform_later(node.id)
        elsif node.needs_compilation?
          LearningNodeCompilationJob.perform_later(node.id)
        end

        LearningRebalancingService.new(node: node).call if node.crowded?
      end
    rescue StandardError => e
      Rails.logger.error("Learning maintenance failed user=#{user.id}: #{e.class} #{e.message}")
    end
  end
end
