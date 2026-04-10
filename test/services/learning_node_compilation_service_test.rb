require "test_helper"

class LearningNodeCompilationServiceTest < ActiveSupport::TestCase
  test "updates node note, creates child topics, and links related notes" do
    user = create_user(app_mode: :life)
    related_node = create_learning_node(user: user, title: "Roman Law")
    node = create_learning_node(user: user, title: "Ancient Rome", body_markdown: nil, status: :pending_research)
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

    GeminiService.stub(:generate_structured_payload, payload) do
      LearningNodeCompilationService.new(node: node).call
    end

    assert_equal "Ancient Rome is best understood through institutions, chronology, and everyday civic life.", node.reload.summary
    assert_includes node.body_markdown, "[[Roman Republic]]"
    assert node.metadata["compiled_source_digest"].present?

    republic = node.children.find_by!(title: "Roman Republic")
    assert republic.pending_research?

    assert node.outgoing_learning_node_links.related.exists?(to_node: related_node)
  end
end
