require "test_helper"

class LearningQuestionAnsweringServiceTest < ActiveSupport::TestCase
  test "answers a topic question with citations" do
    user = create_user(app_mode: :life)
    node = create_learning_node(
      user: user,
      title: "Ancient Rome",
      body_markdown: "## Current Understanding\n\nRome developed durable civic and imperial institutions."
    )
    source = create_learning_source(
      node: node,
      title: "Roman institutions",
      summary_markdown: "## Source Overview\n\nThis source explains the senate, magistrates, and assemblies."
    )
    question = node.learning_questions.create!(question_text: "What institutions mattered most?")

    payload = {
      "answer_markdown" => "## Answer\n\nThe senate, magistracies, and assemblies formed the institutional core.",
      "citations" => [
        {
          "source_id" => source.id,
          "title" => "Roman institutions",
          "reason" => "Explains the institutional roles directly."
        }
      ]
    }

    GeminiService.stub(:generate_structured_payload, payload) do
      LearningQuestionAnsweringService.new(question: question).call
    end

    assert question.reload.answered?
    assert_includes question.answer_markdown, "senate"
    assert_equal source.id, question.citations_data.first["source_id"]
  end
end
