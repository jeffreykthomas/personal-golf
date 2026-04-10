require "test_helper"

class LearningMaintenanceJobTest < ActiveSupport::TestCase
  test "queues discovery for pending nodes and compilation for stale nodes" do
    user = create_user(app_mode: :life)
    pending_node = create_learning_node(user: user, title: "Ancient Rome", status: :pending_research)
    stale_node = create_learning_node(user: user, title: "Roman Law")
    stale_node.update_column(:metadata, { "compiled_source_digest" => "outdated" }) # rubocop:disable Rails/SkipsModelValidations

    assert_enqueued_with(job: LearningSourceDiscoveryJob, args: [pending_node.id]) do
      assert_enqueued_with(job: LearningNodeCompilationJob, args: [stale_node.id]) do
        LearningMaintenanceJob.perform_now
      end
    end
  end
end
