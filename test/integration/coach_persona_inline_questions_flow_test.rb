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

  test "life-mode coach response includes a persona prompt (dilemma by default)" do
    post coach_sessions_path, params: { phase: "pre_round" }, as: :json
    session_id = JSON.parse(response.body).fetch("session").fetch("id")

    post coach_session_coach_messages_path(session_id), params: {
      coach_message: { content: "Hi coach", modality: "text" }
    }, as: :json

    assert_response :success
    payload = JSON.parse(response.body)
    prompt = payload.dig("message", "prompt") || payload["prompt"]

    refute_nil prompt, "expected an inline persona prompt"
    assert_includes %w[persona_question persona_dilemma], prompt["kind"]
    assert prompt["options"].any?
  end

  test "answering a dilemma persists trait signals and history" do
    post coach_sessions_path, params: { phase: "pre_round" }, as: :json
    session_id = JSON.parse(response.body).fetch("session").fetch("id")

    dilemma = PersonaDilemmaBank::DILEMMAS.first
    chosen = dilemma.options.first

    post coach_session_coach_messages_path(session_id), params: {
      coach_message: { content: chosen.label, modality: "text" },
      context: {
        persona_answer: {
          kind: "persona_dilemma",
          dilemma_id: dilemma.id,
          option_id: chosen.id
        }
      }
    }, as: :json

    assert_response :success
    profile = @user.reload.coach_profile.profile_data
    chosen.signals.each do |category, traits|
      traits.each do |trait, weight|
        assert_in_delta weight.to_f, profile.dig("persona_signals", category, trait).to_f, 0.001
      end
    end
    assert(profile.fetch("persona_dilemma_history").any? { |entry| entry["id"] == dilemma.id })
  end

  test "answering a persona_question still works for inventory slots" do
    bank_ids = PersonaDilemmaBank::DILEMMAS.map(&:id)
    @user.create_coach_profile!(
      profile_data: {
        "persona_dilemma_history" => bank_ids.map { |id| { "id" => id, "answered_at" => Time.current.iso8601 } }
      }
    )

    post coach_sessions_path, params: { phase: "pre_round" }, as: :json
    session_id = JSON.parse(response.body).fetch("session").fetch("id")

    post coach_session_coach_messages_path(session_id), params: {
      coach_message: { content: "Family, Growth", modality: "text" },
      context: {
        persona_answer: {
          kind: "persona_question",
          slot: "core_values",
          value: [ "Family", "Growth" ],
          skipped: false
        }
      }
    }, as: :json

    assert_response :success
    persona = @user.reload.coach_profile.profile_data.fetch("persona")
    assert_equal [ "Family", "Growth" ], persona["core_values"]["value"]
  end

  test "skipping a dilemma stores skip state" do
    post coach_sessions_path, params: { phase: "pre_round" }, as: :json
    session_id = JSON.parse(response.body).fetch("session").fetch("id")

    dilemma = PersonaDilemmaBank::DILEMMAS.first

    post coach_session_coach_messages_path(session_id), params: {
      coach_message: { content: "Skip", modality: "text" },
      context: {
        persona_answer: {
          kind: "persona_dilemma",
          dilemma_id: dilemma.id,
          skipped: true
        }
      }
    }, as: :json

    assert_response :success
    profile = @user.reload.coach_profile.profile_data
    assert(profile.fetch("persona_dilemma_history").any? { |entry| entry["id"] == dilemma.id && entry["skipped_at"].present? })
  end
end
