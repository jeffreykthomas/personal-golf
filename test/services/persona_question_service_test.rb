require "test_helper"

class PersonaQuestionServiceTest < ActiveSupport::TestCase
  setup do
    @user = create_user(app_mode: :life)
    @session = @user.coach_sessions.create!(phase: :pre_round, status: :active)
  end

  test "next_slot returns the first persona slot when nothing is filled" do
    service = PersonaQuestionService.new(user: @user, coach_session: @session)
    assert_equal PersonaInventory::SLOTS.first.key, service.next_slot.key
  end

  test "skips slots that already have a value" do
    @user.create_coach_profile!(
      profile_data: {
        "persona" => {
          PersonaInventory::SLOTS.first.key => {
            "value" => [ "Family", "Growth" ],
            "updated_at" => Time.current.iso8601
          }
        }
      }
    )

    service = PersonaQuestionService.new(user: @user, coach_session: @session)
    assert_equal PersonaInventory::SLOTS.second.key, service.next_slot.key
  end

  test "should_offer_inline_question? false for golf mode users" do
    golf_user = create_user(app_mode: :golf)
    session = golf_user.coach_sessions.create!(phase: :pre_round, status: :active)
    service = PersonaQuestionService.new(user: golf_user, coach_session: session)

    refute service.should_offer_inline_question?
  end

  test "record_answer! persists value and freeform under persona slot" do
    service = PersonaQuestionService.new(user: @user, coach_session: @session)
    service.record_answer!("core_values", value: [ "Family", "Growth" ], freeform: "Showing up consistently")

    persona = @user.coach_profile.profile_data.fetch("persona")
    assert_equal [ "Family", "Growth" ], persona["core_values"]["value"]
    assert_equal "Showing up consistently", persona["core_values"]["freeform"]
  end

  test "record_answer! coerces single-select values to a string" do
    service = PersonaQuestionService.new(user: @user, coach_session: @session)
    service.record_answer!("energy_window", value: [ "Early morning" ])

    persona = @user.coach_profile.profile_data.fetch("persona")
    assert_equal "Early morning", persona["energy_window"]["value"]
  end

  test "record_skip! marks slot as skipped without removing prior value" do
    service = PersonaQuestionService.new(user: @user, coach_session: @session)
    service.record_skip!("core_values")

    persona = @user.coach_profile.profile_data.fetch("persona")
    assert persona["core_values"]["skipped_at"].present?
    assert_equal 1, persona["core_values"]["skip_count"]
  end

  test "skipped slots are deprioritized but resurface after cooldown" do
    @user.create_coach_profile!(
      profile_data: {
        "persona" => {
          PersonaInventory::SLOTS.first.key => {
            "skipped_at" => 1.hour.ago.iso8601
          }
        }
      }
    )

    service_now = PersonaQuestionService.new(user: @user, coach_session: @session)
    refute_equal PersonaInventory::SLOTS.first.key, service_now.next_slot.key

    @user.coach_profile.update!(
      profile_data: {
        "persona" => {
          PersonaInventory::SLOTS.first.key => {
            "skipped_at" => 30.days.ago.iso8601
          }
        }
      }
    )

    service_later = PersonaQuestionService.new(user: @user.reload, coach_session: @session)
    assert_equal PersonaInventory::SLOTS.first.key, service_later.next_slot.key
  end

  test "should_offer_inline_question? respects recent persona prompt cooldown" do
    @session.coach_messages.create!(
      role: :assistant,
      modality: :text,
      content: "Hi",
      metadata: {
        "prompt" => { "kind" => "persona_question", "slot" => "core_values" }
      }
    )

    service = PersonaQuestionService.new(user: @user, coach_session: @session)
    refute service.should_offer_inline_question?
  end
end
