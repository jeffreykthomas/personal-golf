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

    GeminiService.stub(:generate_structured_payload, payload) do
      assert_difference -> { node.learning_sources.count }, +1 do
        LearningSourceDiscoveryService.new(node: node).call
      end
    end

    source = node.learning_sources.find_by!(url: "https://example.com/republic")
    assert source.agent_found?
    assert_equal 88, source.quality_score
    assert_equal "History Press", source.publication_name
  end
end
