require "test_helper"

class LearningNodesSuggestionsTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user(app_mode: :life)
    @node = create_learning_node(user: @user, title: "Ancient Rome")
    @node.update!(metadata: @node.metadata.merge(
      "suggested_child_topics" => [
        { "title" => "Roman Republic", "summary" => "Political formation" },
        { "title" => "Imperial Rome", "summary" => "Imperial phase" }
      ]
    ))

    sign_in_as(@user)
  end

  test "promoting a suggestion creates a draft child and removes the suggestion" do
    assert_no_enqueued_jobs(only: [LearningSourceDiscoveryJob]) do
      post promote_suggestion_learning_node_path(@node), params: { title: "Roman Republic" }
    end

    child = @user.learning_nodes.find_by(title: "Roman Republic")
    assert child.present?
    assert_equal @node.id, child.parent_id
    assert child.draft?

    titles = @node.reload.metadata["suggested_child_topics"].map { |entry| entry["title"] }
    refute_includes titles, "Roman Republic"
    assert_includes titles, "Imperial Rome"
  end

  test "dismissing a suggestion adds it to dismissed list" do
    post dismiss_suggestion_learning_node_path(@node), params: { title: "Imperial Rome" }

    @node.reload
    titles = @node.metadata["suggested_child_topics"].map { |entry| entry["title"] }
    refute_includes titles, "Imperial Rome"
    assert_includes Array(@node.metadata["dismissed_suggestion_titles"]), "Imperial Rome"
  end

  test "promotion is a no-op when suggestion no longer exists" do
    post promote_suggestion_learning_node_path(@node), params: { title: "Nonexistent" }

    assert_equal 0, @user.learning_nodes.where(parent: @node).count
  end
end
