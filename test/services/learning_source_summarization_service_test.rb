require "test_helper"
require "tempfile"

class LearningSourceSummarizationServiceTest < ActiveSupport::TestCase
  test "summarizes a text upload through the NanoClaw bridge" do
    user = create_user(app_mode: :life)
    node = create_learning_node(user: user, title: "Ancient Rome")
    source = node.learning_sources.new(
      title: "Roman Republic notes",
      source_type: :upload,
      extraction_status: :discovered
    )

    tempfile = Tempfile.new(["rome", ".md"])
    tempfile.write("# Roman Republic\n\nThe senate and magistrates shaped civic life.")
    tempfile.rewind

    source.uploaded_file.attach(
      io: tempfile,
      filename: "rome.md",
      content_type: "text/markdown"
    )
    source.save!
    source.update_column(:metadata, { "last_error" => "old failure" }) # rubocop:disable Rails/SkipsModelValidations

    payload = {
      "title" => "Roman Republic",
      "summary_markdown" => "## Source Overview\n\nThis source explains the senate and magistracies.",
      "key_points" => ["Senate", "Magistrates", "Assemblies"]
    }

    NanoclawLearningBridgeService.stub(:summarize_source, payload) do
      LearningSourceSummarizationService.new(source: source).call
    end

    assert source.reload.summarized?
    assert_includes source.summary_markdown, "senate"
    assert_equal ["Senate", "Magistrates", "Assemblies"], source.metadata["key_points"]
    assert_nil source.metadata["last_error"]
  ensure
    tempfile&.close!
  end
end
