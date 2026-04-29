class LearningMaintenanceJob < ApplicationJob
  queue_as :ai_generation

  # Nodes touched more recently than this are skipped by the nightly sweep to
  # avoid re-running the agent on freshly-edited or freshly-compiled notes.
  RECENT_ACTIVITY_WINDOW = 3.days

  # Hard ceiling on how many agent jobs the nightly sweep will enqueue per run
  # across all users. Prevents a large vault from spawning dozens of containers
  # at once. Rebalancing is cheap and not counted toward this cap.
  MAX_AGENT_ENQUEUES_PER_RUN = 5

  def perform(user_ids = nil)
    scope = User.life
    scope = scope.where(id: Array(user_ids)) if user_ids.present?

    cutoff = RECENT_ACTIVITY_WINDOW.ago
    remaining = MAX_AGENT_ENQUEUES_PER_RUN

    scope.find_each do |user|
      user.learning_nodes.order(:updated_at).find_each do |node|
        node.sync_wikilinks!

        LearningRebalancingService.new(node: node).call if node.crowded?

        next if node.updated_at.present? && node.updated_at > cutoff
        next if remaining <= 0

        if node.pending_research? && node.learning_sources.none?
          LearningSourceDiscoveryJob.perform_later(node.id)
          remaining -= 1
        elsif node.needs_compilation?
          LearningNodeCompilationJob.perform_later(node.id)
          remaining -= 1
        end
      end
    rescue StandardError => e
      Rails.logger.error("Learning maintenance failed user=#{user.id}: #{e.class} #{e.message}")
    end
  end
end
