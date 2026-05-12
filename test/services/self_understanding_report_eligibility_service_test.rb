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
    create_existing_report(user:, evaluation: first_pass)

    second_pass = SelfUnderstandingReportEligibilityService.new(user: user).evaluate

    assert_not second_pass.should_generate?
    assert_equal "unchanged", second_pass.reason
  end

  test "daily account age changes do not count as new report signal" do
    user = create_user(app_mode: :life, goals: ["build more clarity"], created_at: 10.days.ago)
    user.create_coach_profile!(profile_data: { reflection_style: "thoughtful" })

    first_pass = SelfUnderstandingReportEligibilityService.new(user: user).evaluate
    create_existing_report(user:, evaluation: first_pass)

    travel 1.day do
      second_pass = SelfUnderstandingReportEligibilityService.new(user: user).evaluate

      assert_not second_pass.should_generate?
      assert_equal "unchanged", second_pass.reason
      assert_not_equal first_pass.source_snapshot.dig(:user_profile, :account_age_days),
                       second_pass.source_snapshot.dig(:user_profile, :account_age_days)
      assert_equal first_pass.source_digest, second_pass.source_digest
    end
  end

  test "profile sync timestamp changes do not count as new report signal when facts are unchanged" do
    user = create_user(app_mode: :life, goals: ["build more clarity"])
    coach_profile = user.create_coach_profile!(profile_data: { reflection_style: "thoughtful" }, last_synced_at: 2.days.ago)

    first_pass = SelfUnderstandingReportEligibilityService.new(user: user).evaluate
    create_existing_report(user:, evaluation: first_pass)

    coach_profile.update!(last_synced_at: Time.current)

    second_pass = SelfUnderstandingReportEligibilityService.new(user: user).evaluate

    assert_not second_pass.should_generate?
    assert_equal "unchanged", second_pass.reason
    assert_not_equal first_pass.source_snapshot.dig(:coach_profile, :last_synced_at),
                     second_pass.source_snapshot.dig(:coach_profile, :last_synced_at)
    assert_equal first_pass.source_digest, second_pass.source_digest
  end

  test "legacy reports with volatile digests skip when stable source snapshot is unchanged" do
    user = create_user(app_mode: :life, goals: ["build more clarity"], created_at: 10.days.ago)
    user.create_coach_profile!(profile_data: { reflection_style: "thoughtful" }, last_synced_at: 2.days.ago)

    first_pass = SelfUnderstandingReportEligibilityService.new(user: user).evaluate
    legacy_digest = Digest::SHA256.hexdigest(JSON.generate(first_pass.source_snapshot))
    create_existing_report(user:, evaluation: first_pass, source_digest: legacy_digest)

    travel 1.day do
      second_pass = SelfUnderstandingReportEligibilityService.new(user: user).evaluate

      assert_not second_pass.should_generate?
      assert_equal "unchanged", second_pass.reason
    end
  end

  test "new coach facts still count as new report signal" do
    user = create_user(app_mode: :life, goals: ["build more clarity"])
    coach_profile = user.create_coach_profile!(profile_data: { reflection_style: "thoughtful" })

    first_pass = SelfUnderstandingReportEligibilityService.new(user: user).evaluate
    create_existing_report(user:, evaluation: first_pass)

    coach_profile.update!(profile_data: { reflection_style: "thoughtful", preferred_pace: "slow" })

    second_pass = SelfUnderstandingReportEligibilityService.new(user: user).evaluate

    assert second_pass.should_generate?
    assert_equal "new_signal", second_pass.reason
    assert_not_equal first_pass.source_digest, second_pass.source_digest
  end

  private

  def create_existing_report(user:, evaluation:, source_digest: evaluation.source_digest)
    user.self_understanding_reports.create!(
      framework_name: "Nine Currents",
      title: "Existing report",
      body_markdown: "## Overall pattern\n\nStable.",
      currents_data: { "currents" => [] },
      source_snapshot: evaluation.source_snapshot,
      source_digest: source_digest,
      source_updated_at: evaluation.source_updated_at,
      generated_at: Time.current
    )
  end
end
