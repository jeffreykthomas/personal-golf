require "test_helper"

class ClawBridgeServiceTest < ActiveSupport::TestCase
  setup do
    @user = create_user(app_mode: :life, onboarding_completed: true)
    @session = @user.coach_sessions.create!(phase: :pre_round, status: :active)
  end

  test "decorates response with a persona dilemma for life mode users" do
    result = ClawBridgeService.new(user: @user, coach_session: @session).respond_to(
      message: "Hello",
      context: {}
    )

    assert result[:prompt].is_a?(Hash)
    assert_equal "persona_dilemma", result[:prompt][:kind]
    assert result[:prompt][:dilemma_id].present?
    assert result[:prompt][:options].any?
    assert(result[:prompt][:options].all? { |opt| opt[:id].present? && opt[:label].present? })
    assert_includes PersonaDilemmaBank::CATEGORIES, result[:prompt][:category]
    assert_equal 1, result[:prompt][:max_options]
    refute result[:prompt][:multi_select]
  end

  test "falls back to inventory slot when dilemmas are exhausted" do
    bank_ids = PersonaDilemmaBank::DILEMMAS.map(&:id)
    @user.create_coach_profile!(
      profile_data: {
        "persona_dilemma_history" => bank_ids.map { |id| { "id" => id, "answered_at" => Time.current.iso8601 } }
      }
    )

    result = ClawBridgeService.new(user: @user.reload, coach_session: @session).respond_to(
      message: "Hello",
      context: {}
    )

    assert result[:prompt].is_a?(Hash)
    assert_equal "persona_question", result[:prompt][:kind]
    assert_equal PersonaInventory::SLOTS.first.key, result[:prompt][:slot]
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

  test "persists persona answer when context includes a persona_question answer" do
    result = ClawBridgeService.new(user: @user, coach_session: @session).respond_to(
      message: "Family, Growth",
      context: {
        "persona_answer" => {
          "kind" => "persona_question",
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
          "kind" => "persona_question",
          "slot" => "core_values",
          "skipped" => true
        }
      }
    )

    persona = @user.reload.coach_profile.profile_data.fetch("persona")
    assert persona["core_values"]["skipped_at"].present?
    assert_match(/skip/i, result[:text])
  end

  test "persists trait signals when a dilemma answer arrives" do
    dilemma = PersonaDilemmaBank::DILEMMAS.first
    chosen = dilemma.options.first

    result = ClawBridgeService.new(user: @user, coach_session: @session).respond_to(
      message: chosen.label,
      context: {
        "persona_answer" => {
          "kind" => "persona_dilemma",
          "dilemma_id" => dilemma.id,
          "option_id" => chosen.id
        }
      }
    )

    profile = @user.reload.coach_profile.profile_data
    chosen.signals.each do |category, traits|
      traits.each do |trait, weight|
        actual = profile.dig("persona_signals", category, trait)
        assert_in_delta weight.to_f, actual.to_f, 0.001,
          "expected signal #{category}.#{trait} to record weight #{weight}"
      end
    end

    history = profile.fetch("persona_dilemma_history")
    assert(history.any? { |entry| entry["id"] == dilemma.id && entry["option_id"] == chosen.id })
    assert_match(/Got it/i, result[:text])
  end

  test "skipped dilemma is recorded but no signals applied" do
    dilemma = PersonaDilemmaBank::DILEMMAS.first

    ClawBridgeService.new(user: @user, coach_session: @session).respond_to(
      message: "Skip",
      context: {
        "persona_answer" => {
          "kind" => "persona_dilemma",
          "dilemma_id" => dilemma.id,
          "skipped" => true
        }
      }
    )

    profile = @user.reload.coach_profile.profile_data
    assert_nil profile["persona_signals"]
    history = profile.fetch("persona_dilemma_history")
    assert(history.any? { |entry| entry["id"] == dilemma.id && entry["skipped_at"].present? })
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
