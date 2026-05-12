require "test_helper"

class PersonaPromptOrchestratorTest < ActiveSupport::TestCase
  setup do
    @user = create_user(app_mode: :life)
    @session = @user.coach_sessions.create!(phase: :pre_round, status: :active)
  end

  test "should_offer_prompt? is false for golf-mode users" do
    golf = create_user(app_mode: :golf)
    session = golf.coach_sessions.create!(phase: :pre_round, status: :active)

    refute PersonaPromptOrchestrator.new(user: golf, coach_session: session).should_offer_prompt?
  end

  test "first prompt is a dilemma" do
    payload = PersonaPromptOrchestrator.new(user: @user, coach_session: @session).next_payload
    assert_equal "persona_dilemma", payload[:kind]
  end

  test "falls back to inventory once dilemmas are exhausted" do
    bank_ids = PersonaDilemmaBank::DILEMMAS.map(&:id)
    @user.create_coach_profile!(
      profile_data: {
        "persona_dilemma_history" => bank_ids.map { |id| { "id" => id, "answered_at" => Time.current.iso8601 } }
      }
    )

    payload = PersonaPromptOrchestrator.new(user: @user.reload, coach_session: @session).next_payload
    assert_equal "persona_question", payload[:kind]
    assert_equal PersonaInventory::SLOTS.first.key, payload[:slot]
    assert(payload[:options].all? { |opt| opt[:id].present? && opt[:label].present? })
  end

  test "respects recent persona prompt cooldown across both kinds" do
    @session.coach_messages.create!(
      role: :assistant,
      modality: :text,
      content: "Asked",
      metadata: { "prompt" => { "kind" => "persona_dilemma", "dilemma_id" => "anything" } }
    )

    refute PersonaPromptOrchestrator.new(user: @user, coach_session: @session).should_offer_prompt?
  end
end
