require "test_helper"

class LearningResearchServiceTest < ActiveSupport::TestCase
  test "applies claw research payload to sources and compiled note" do
    user = create_user(app_mode: :life)
    related_node = create_learning_node(user: user, title: "Roman Law")
    node = create_learning_node(user: user, title: "Ancient Rome", body_markdown: nil, status: :pending_research)

    payload = {
      "sources" => [
        {
          "title" => "The Roman Republic",
          "url" => "https://example.com/republic",
          "publication_name" => "History Press",
          "author_name" => "A. Historian",
          "published_on" => "2024-04-10",
          "quality_score" => 88,
          "why_relevant" => "High-level overview with strong historical framing.",
          "summary_markdown" => "## Source Overview\n\nA reliable overview of republican institutions.",
          "key_points" => ["Magistrates", "Senate"]
        }
      ],
      "summary" => "Ancient Rome is best understood through institutions, chronology, and everyday civic life.",
      "body_markdown" => "## Current Understanding\n\nAncient Rome blended institutions, conquest, and civic identity.\n\n## Structure\n\n- [[Roman Republic]]\n- [[Imperial Rome]]",
      "child_topics" => [
        { "title" => "Roman Republic", "summary" => "Political formation and republican institutions." },
        { "title" => "Imperial Rome", "summary" => "The imperial phase and administrative scale." }
      ],
      "related_topics" => ["Roman Law"],
      "open_questions" => ["Which primary sources best explain daily civic life?"]
    }

    NanoclawLearningBridgeService.stub(:research_node, payload) do
      LearningResearchService.new(node: node).call
    end

    source = node.learning_sources.find_by!(url: "https://example.com/republic")
    assert source.summarized?
    assert_equal ["Magistrates", "Senate"], source.metadata["key_points"]

    assert_equal "Ancient Rome is best understood through institutions, chronology, and everyday civic life.", node.reload.summary
    assert node.metadata["last_researched_at"].present?
    assert_equal "nanoclaw", node.metadata["last_research_source"]

    assert_equal 0, node.children.count, "Research must not auto-create child nodes"
    suggestions = node.metadata["suggested_child_topics"]
    assert_equal ["Roman Republic", "Imperial Rome"], suggestions.map { |entry| entry["title"] }

    assert node.outgoing_learning_node_links.related.exists?(to_node: related_node)
  end
end
