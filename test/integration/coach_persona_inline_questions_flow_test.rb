require "test_helper"

class CoachPersonaInlineQuestionsFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user(app_mode: :life, onboarding_completed: true)
    sign_in_as(@user)
    ENV["ENABLE_COACH_AGENT"] = "true"
  end

  teardown do
    ENV.delete("ENABLE_COACH_AGENT")
  end

  test "life-mode coach response includes a persona question prompt" do
    post coach_sessions_path, params: { phase: "pre_round" }, as: :json
    session_id = JSON.parse(response.body).fetch("session").fetch("id")

    post coach_session_coach_messages_path(session_id), params: {
      coach_message: { content: "Hi coach", modality: "text" }
    }, as: :json

    assert_response :success
    payload = JSON.parse(response.body)
    prompt = payload.dig("message", "prompt") || payload["prompt"]

    refute_nil prompt, "expected an inline persona question prompt"
    assert_equal "persona_question", prompt["kind"]
    assert prompt["options"].any?, "expected option chips"
  end

  test "answering a persona question persists the answer" do
    post coach_sessions_path, params: { phase: "pre_round" }, as: :json
    session_id = JSON.parse(response.body).fetch("session").fetch("id")

    post coach_session_coach_messages_path(session_id), params: {
      coach_message: { content: "Family, Growth", modality: "text" },
      context: {
        persona_answer: {
          slot: "core_values",
          value: [ "Family", "Growth" ],
          skipped: false
        }
      }
    }, as: :json

    assert_response :success
    persona = @user.reload.coach_profile.profile_data.fetch("persona")
    assert_equal [ "Family", "Growth" ], persona["core_values"]["value"]

    response_text = JSON.parse(response.body).dig("message", "content")
    assert_match(/saved that/i, response_text)
  end

  test "skipping a persona question stores skip state" do
    post coach_sessions_path, params: { phase: "pre_round" }, as: :json
    session_id = JSON.parse(response.body).fetch("session").fetch("id")

    post coach_session_coach_messages_path(session_id), params: {
      coach_message: { content: "Skip", modality: "text" },
      context: {
        persona_answer: {
          slot: "core_values",
          skipped: true
        }
      }
    }, as: :json

    assert_response :success
    persona = @user.reload.coach_profile.profile_data.fetch("persona")
    assert persona["core_values"]["skipped_at"].present?
  end
end
