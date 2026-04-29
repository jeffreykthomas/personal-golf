require "test_helper"

class LearningMaintenanceJobTest < ActiveSupport::TestCase
  test "queues discovery for pending nodes and compilation for stale nodes" do
    user = create_user(app_mode: :life)
    pending_node = create_learning_node(user: user, title: "Ancient Rome", status: :pending_research)
    stale_node = create_learning_node(user: user, title: "Roman Law")
    stale_node.update_column(:metadata, { "compiled_source_digest" => "outdated" }) # rubocop:disable Rails/SkipsModelValidations

    backdate([pending_node, stale_node])

    assert_enqueued_with(job: LearningSourceDiscoveryJob, args: [pending_node.id]) do
      assert_enqueued_with(job: LearningNodeCompilationJob, args: [stale_node.id]) do
        LearningMaintenanceJob.perform_now
      end
    end
  end

  test "skips nodes updated within the recent activity window" do
    user = create_user(app_mode: :life)
    fresh_node = create_learning_node(user: user, title: "Fresh", status: :pending_research)

    assert_no_enqueued_jobs(only: [LearningSourceDiscoveryJob, LearningNodeCompilationJob]) do
      LearningMaintenanceJob.perform_now
    end

    assert_not_nil fresh_node
  end

  test "caps the number of agent enqueues per run" do
    user = create_user(app_mode: :life)

    nodes = (LearningMaintenanceJob::MAX_AGENT_ENQUEUES_PER_RUN + 3).times.map do |i|
      create_learning_node(user: user, title: "Pending #{i}", status: :pending_research)
    end

    backdate(nodes)

    assert_enqueued_jobs(LearningMaintenanceJob::MAX_AGENT_ENQUEUES_PER_RUN, only: LearningSourceDiscoveryJob) do
      LearningMaintenanceJob.perform_now
    end
  end

  private

  def backdate(nodes, by: LearningMaintenanceJob::RECENT_ACTIVITY_WINDOW + 1.day)
    timestamp = by.ago
    Array(nodes).each do |node|
      LearningNode.where(id: node.id).update_all(updated_at: timestamp) # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
