require "test_helper"

class SelfUnderstandingReportEligibilityServiceTest < ActiveSupport::TestCase
  test "life mode with meaningful signal is eligible for a first report" do
    user = create_user(app_mode: :life, goals: ["build more clarity"])
    user.create_coach_profile!(profile_data: { reflection_style: "thoughtful" })

    result = SelfUnderstandingReportEligibilityService.new(user: user).evaluate

    assert result.should_generate?
    assert_equal "first_report", result.reason
    assert result.source_digest.present?
  end

  test "golf mode is not eligible even when signal exists" do
    user = create_user(app_mode: :golf, goals: ["build more clarity"])
    user.create_coach_profile!(profile_data: { reflection_style: "thoughtful" })

    result = SelfUnderstandingReportEligibilityService.new(user: user).evaluate

    assert_not result.should_generate?
    assert_equal "not_in_life_mode", result.reason
  end

  test "unchanged source digest skips regeneration" do
    user = create_user(app_mode: :life, goals: ["build more clarity"])
    user.create_coach_profile!(profile_data: { reflection_style: "thoughtful" })

    first_pass = SelfUnderstandingReportEligibilityService.new(user: user).evaluate
    user.self_understanding_reports.create!(
      framework_name: "Nine Currents",
      title: "Existing report",
      body_markdown: "## Overall pattern\n\nStable.",
      currents_data: { "currents" => [] },
      source_snapshot: first_pass.source_snapshot,
      source_digest: first_pass.source_digest,
      source_updated_at: first_pass.source_updated_at,
      generated_at: Time.current
    )

    second_pass = SelfUnderstandingReportEligibilityService.new(user: user).evaluate

    assert_not second_pass.should_generate?
    assert_equal "unchanged", second_pass.reason
  end
end
