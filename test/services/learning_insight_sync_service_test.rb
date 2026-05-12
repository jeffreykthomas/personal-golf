require "test_helper"

class LearningInsightSyncServiceTest < ActiveSupport::TestCase
  test "syncs saved coach insights into categorized learning nodes" do
    user = create_user(app_mode: :life)
    category = create_category(name: "Preferences")
    insight = Insight.create!(
      user: user,
      category: category,
      title: "Values slow mornings",
      content: "I do my best thinking before the day becomes noisy.",
      published: true
    )
    user.save_tip(insight)

    assert_difference -> { user.learning_nodes.count }, +3 do
      LearningInsightSyncService.new(user: user).call
    end

    root = user.learning_nodes.find_by!(title: "Personal Beliefs")
    category_node = user.learning_nodes.find_by!(title: "Preferences")
    insight_node = user.learning_nodes.find_by!(title: "Values slow mornings")

    assert root.cluster?
    assert_equal root.id, category_node.parent_id
    assert category_node.cluster?
    assert_equal category_node.id, insight_node.parent_id
    assert insight_node.generated_note?
    assert insight_node.ready?
    assert_equal "coach_insight", insight_node.metadata["source"]
    assert_equal insight.id, insight_node.metadata["tip_id"]
    assert_includes insight_node.body_markdown, insight.content
  end

  test "sync is idempotent" do
    user = create_user(app_mode: :life)
    insight = Insight.create!(
      user: user,
      title: "Protect deep work",
      content: "Long uninterrupted blocks make hard projects feel possible.",
      published: true
    )
    user.save_tip(insight)

    LearningInsightSyncService.new(user: user).call

    assert_no_difference -> { user.learning_nodes.count } do
      LearningInsightSyncService.new(user: user).call
    end
  end

  test "does not create a personal beliefs root without saved insights" do
    user = create_user(app_mode: :life)

    assert_no_difference -> { user.learning_nodes.count } do
      LearningInsightSyncService.new(user: user).call
    end
  end
end
