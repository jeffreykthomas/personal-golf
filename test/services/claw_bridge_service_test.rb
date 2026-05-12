require "test_helper"

class ClawBridgeServiceTest < ActiveSupport::TestCase
  setup do
    @user = create_user(app_mode: :life, onboarding_completed: true)
    @session = @user.coach_sessions.create!(phase: :pre_round, status: :active)
  end

  test "decorates response with persona prompt for life mode users" do
    result = ClawBridgeService.new(user: @user, coach_session: @session).respond_to(
      message: "Hello",
      context: {}
    )

    assert result[:prompt].is_a?(Hash)
    assert_equal "persona_question", result[:prompt][:kind]
    assert_equal PersonaInventory::SLOTS.first.key, result[:prompt][:slot]
    assert result[:prompt][:options].any?
    assert_includes result[:text], result[:prompt][:question]
  end

  test "does not attach a persona prompt for golf mode users" do
    golf_user = create_user(app_mode: :golf, onboarding_completed: true)
    session = golf_user.coach_sessions.create!(phase: :pre_round, status: :active)

    result = ClawBridgeService.new(user: golf_user, coach_session: session).respond_to(
      message: "Hello",
      context: {}
    )

    assert_nil result[:prompt]
  end

  test "persists persona answer when context includes persona_answer" do
    result = ClawBridgeService.new(user: @user, coach_session: @session).respond_to(
      message: "Family, Growth",
      context: {
        "persona_answer" => {
          "slot" => "core_values",
          "value" => [ "Family", "Growth" ],
          "freeform" => nil,
          "skipped" => false
        }
      }
    )

    persona = @user.reload.coach_profile.profile_data.fetch("persona")
    assert_equal [ "Family", "Growth" ], persona["core_values"]["value"]
    assert_match(/Saved that/i, result[:text])
  end

  test "skips question when context indicates skipped" do
    result = ClawBridgeService.new(user: @user, coach_session: @session).respond_to(
      message: "Skip — Core values",
      context: {
        "persona_answer" => {
          "slot" => "core_values",
          "skipped" => true
        }
      }
    )

    persona = @user.reload.coach_profile.profile_data.fetch("persona")
    assert persona["core_values"]["skipped_at"].present?
    assert_match(/skip/i, result[:text])
  end

  test "does not attach persona prompt during onboarding session" do
    onboarding = @user.coach_sessions.create!(phase: :onboarding, status: :active)
    result = ClawBridgeService.new(user: @user, coach_session: onboarding).respond_to(
      message: "Hi",
      context: {}
    )

    assert_nil result[:prompt]
  end
end
