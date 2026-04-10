require "test_helper"
require "tempfile"

class LearningSourcesFlowTest < ActionDispatch::IntegrationTest
  test "user can add a url source to a learning node" do
    user = create_user(app_mode: :life)
    node = create_learning_node(user: user)

    sign_in_as(user)

    assert_enqueued_with(job: LearningSourceSummarizationJob) do
      assert_difference -> { node.learning_sources.count }, +1 do
        post learning_node_learning_sources_path(node), params: {
          learning_source: {
            title: "Roman history overview",
            url: "https://example.com/rome"
          }
        }
      end
    end

    source = node.learning_sources.find_by!(url: "https://example.com/rome")
    assert source.user_url?
    assert_redirected_to learning_path(node_id: node.id)
  end

  test "user can upload a file source to a learning node" do
    user = create_user(app_mode: :life)
    node = create_learning_node(user: user)
    tempfile = Tempfile.new(["rome", ".md"])
    tempfile.write("# Roman Republic\n\nFounding and institutions.")
    tempfile.rewind

    sign_in_as(user)

    uploaded_file = Rack::Test::UploadedFile.new(tempfile.path, "text/markdown", original_filename: "rome.md")

    assert_enqueued_with(job: LearningSourceSummarizationJob) do
      assert_difference -> { node.learning_sources.count }, +1 do
        post learning_node_learning_sources_path(node), params: {
          learning_source: {
            title: "Roman Republic Notes",
            uploaded_file: uploaded_file
          }
        }
      end
    end

    source = node.learning_sources.order(:created_at).last
    assert source.upload?
    assert source.uploaded_file.attached?
    assert_redirected_to learning_path(node_id: node.id)
  ensure
    tempfile&.close!
  end
end
