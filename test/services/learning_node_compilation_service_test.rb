require "test_helper"

class LearningNodeCompilationServiceTest < ActiveSupport::TestCase
  test "updates node note, stores child topic suggestions, and links related notes" do
    user = create_user(app_mode: :life)
    related_node = create_learning_node(user: user, title: "Roman Law")
    node = create_learning_node(
      user: user,
      title: "Ancient Rome",
      body_markdown: nil,
      status: :pending_research,
      metadata: {
        "last_research_error" => "timed out",
        "last_research_failed_at" => Time.current.iso8601
      }
    )
    create_learning_source(
      node: node,
      title: "Roman history source",
      summary_markdown: "## Source Overview\n\nA reliable overview of Roman institutions."
    )

    payload = {
      "summary" => "Ancient Rome is best understood through institutions, chronology, and everyday civic life.",
      "body_markdown" => "## Current Understanding\n\nAncient Rome blended institutions, conquest, and civic identity.\n\n## Structure\n\n- [[Roman Republic]]\n- [[Imperial Rome]]",
      "child_topics" => [
        { "title" => "Roman Republic", "summary" => "Political formation and republican institutions." },
        { "title" => "Imperial Rome", "summary" => "The imperial phase and administrative scale." }
      ],
      "related_topics" => ["Roman Law"],
      "open_questions" => ["Which primary sources best explain daily civic life?"]
    }

    NanoclawLearningBridgeService.stub(:compile_node, payload) do
      LearningNodeCompilationService.new(node: node).call
    end

    node.reload
    assert_equal "Ancient Rome is best understood through institutions, chronology, and everyday civic life.", node.summary
    assert_includes node.body_markdown, "[[Roman Republic]]"
    assert node.metadata["compiled_source_digest"].present?
    assert_nil node.metadata["last_research_error"]
    assert_nil node.metadata["last_research_failed_at"]

    assert_equal 0, node.children.count, "Compilation must not auto-create child nodes"

    suggestions = node.metadata["suggested_child_topics"]
    assert_equal 2, suggestions.size
    assert_equal "Roman Republic", suggestions.first["title"]
    assert_equal "Political formation and republican institutions.", suggestions.first["summary"]

    assert node.outgoing_learning_node_links.related.exists?(to_node: related_node)
  end

  test "omits suggestions that match existing children or previously dismissed titles" do
    user = create_user(app_mode: :life)
    node = create_learning_node(user: user, title: "Ancient Rome")
    create_learning_node(user: user, title: "Roman Republic", parent: node)
    node.update!(metadata: node.metadata.merge("dismissed_suggestion_titles" => ["Imperial Rome"]))

    payload = {
      "summary" => "Summary",
      "body_markdown" => "Body",
      "child_topics" => [
        { "title" => "Roman Republic", "summary" => "..." },
        { "title" => "Imperial Rome", "summary" => "..." },
        { "title" => "Roman Religion", "summary" => "Rites and cults" }
      ]
    }

    NanoclawLearningBridgeService.stub(:compile_node, payload) do
      LearningNodeCompilationService.new(node: node).call
    end

    titles = node.reload.metadata["suggested_child_topics"].map { |entry| entry["title"] }
    assert_equal ["Roman Religion"], titles
  end
end
