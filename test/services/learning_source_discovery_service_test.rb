require "test_helper"

class LearningSourceDiscoveryServiceTest < ActiveSupport::TestCase
  test "creates agent-found learning sources from structured payload" do
    user = create_user(app_mode: :life)
    node = create_learning_node(user: user, title: "Ancient Rome", status: :pending_research)

    payload = {
      "sources" => [
        {
          "title" => "The Roman Republic",
          "url" => "https://example.com/republic",
          "publication_name" => "History Press",
          "author_name" => "A. Historian",
          "published_on" => "2024-04-10",
          "quality_score" => 88,
          "why_relevant" => "High-level overview with strong historical framing."
        }
      ]
    }

    NanoclawLearningBridgeService.stub(:discover_sources, payload) do
      assert_difference -> { node.learning_sources.count }, +1 do
        LearningSourceDiscoveryService.new(node: node).call
      end
    end

    source = node.learning_sources.find_by!(url: "https://example.com/republic")
    assert source.agent_found?
    assert_equal 88, source.quality_score
    assert_equal "History Press", source.publication_name
  end

  test "preserves an existing summary when discovery refreshes source metadata" do
    user = create_user(app_mode: :life)
    node = create_learning_node(user: user, title: "Ancient Rome")
    source = create_learning_source(
      node: node,
      title: "Existing Rome Source",
      url: "https://example.com/republic",
      summary_markdown: "## Existing Summary\n\nKept.",
      extraction_status: :summarized
    )

    payload = {
      "sources" => [
        {
          "title" => "Updated Rome Source",
          "url" => "https://example.com/republic",
          "quality_score" => 92,
          "why_relevant" => "Fresh metadata only."
        }
      ]
    }

    LearningSourceDiscoveryService.new(node: node).call(payload: payload)

    assert_equal "Updated Rome Source", source.reload.title
    assert_equal 92, source.quality_score
    assert_equal "## Existing Summary\n\nKept.", source.summary_markdown
    assert source.summarized?
  end
end
