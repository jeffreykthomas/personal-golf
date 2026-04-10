require "test_helper"

class GenerateSelfUnderstandingReportsJobTest < ActiveSupport::TestCase
  test "job creates reports for eligible life users and skips unchanged reruns" do
    life_user = create_user(app_mode: :life, goals: ["build more clarity"])
    life_user.create_coach_profile!(profile_data: { reflection_style: "thoughtful" })

    golf_user = create_user(app_mode: :golf, goals: ["build more clarity"])
    golf_user.create_coach_profile!(profile_data: { reflection_style: "thoughtful" })

    GeminiService.stub(:generate_self_understanding_report, gemini_payload) do
      assert_difference -> { life_user.self_understanding_reports.count }, +1 do
        assert_no_difference -> { golf_user.self_understanding_reports.count } do
          GenerateSelfUnderstandingReportsJob.perform_now
        end
      end

      assert_no_difference -> { life_user.self_understanding_reports.count } do
        GenerateSelfUnderstandingReportsJob.perform_now
      end
    end
  end

  private

  def gemini_payload
    {
      "title" => "Pattern Snapshot",
      "body_markdown" => "## Overall pattern\n\nThis is a grounded synthesis.",
      "currents" => SelfUnderstandingReport::CURRENT_ORDER.map do |name|
        {
          "name" => name,
          "score" => 6,
          "summary" => "#{name} is moderately active right now.",
          "signals" => ["Observed through recent user behavior."]
        }
      end
    }
  end
end
