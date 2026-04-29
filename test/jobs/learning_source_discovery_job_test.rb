require "test_helper"

class LearningSourceDiscoveryJobTest < ActiveSupport::TestCase
  test "discovers, summarizes, and compiles through the claw-only pipeline" do
    user = create_user(app_mode: :life)
    node = create_learning_node(user: user, title: "Ancient Rome", body_markdown: nil, status: :pending_research)

    discovery_payload = {
      "sources" => [
        {
          "title" => "The Roman Republic",
          "url" => "https://example.com/republic",
          "quality_score" => 88
        },
        {
          "title" => "Imperial Administration",
          "url" => "https://example.com/empire",
          "quality_score" => 84
        }
      ]
    }

    summary_payloads = {
      "https://example.com/republic" => {
        "title" => "The Roman Republic",
        "summary_markdown" => "## Source Overview\n\nRepublic institutions shaped civic life.",
        "key_points" => ["Senate", "Assemblies"]
      },
      "https://example.com/empire" => {
        "title" => "Imperial Administration",
        "summary_markdown" => "## Source Overview\n\nImperial administration scaled governance.",
        "key_points" => ["Emperor", "Provinces"]
      }
    }

    compile_payload = {
      "summary" => "Ancient Rome evolved through republican and imperial institutions.",
      "body_markdown" => "## Current Understanding\n\nAncient Rome combined republican institutions with imperial scale.",
      "child_topics" => [
        { "title" => "Roman Republic", "summary" => "Political formation and civic institutions." }
      ],
      "related_topics" => [],
      "open_questions" => []
    }

    NanoclawLearningBridgeService.stub(:discover_sources, discovery_payload) do
      NanoclawLearningBridgeService.stub(:summarize_source, ->(source:, extracted_content: nil, extracted_title: nil) {
        summary_payloads.fetch(source.url)
      }) do
        NanoclawLearningBridgeService.stub(:compile_node, compile_payload) do
          LearningSourceDiscoveryJob.perform_now(node.id)
        end
      end
    end

    assert_equal 2, node.learning_sources.count
    assert_equal 2, node.learning_sources.summarized.count
    assert_equal "Ancient Rome evolved through republican and imperial institutions.", node.reload.summary
    assert node.body_markdown.present?
    assert_equal ["Senate", "Assemblies"], node.learning_sources.find_by!(url: "https://example.com/republic").metadata["key_points"]
  end
end
