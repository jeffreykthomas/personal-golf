require "test_helper"

class SelfUnderstandingReportsFlowTest < ActionDispatch::IntegrationTest
  test "life mode shows empty state when no report exists" do
    user = create_user(app_mode: :life)

    sign_in_as(user)

    get self_understanding_report_path
    assert_response :success
    assert_select "h2", text: "Your report will appear here"
  end

  test "life mode renders the latest report" do
    user = create_user(app_mode: :life)
    user.self_understanding_reports.create!(
      framework_name: "Nine Currents",
      title: "Pattern Snapshot",
      body_markdown: "## Overall pattern\n\nYou are balancing curiosity with steadiness.",
      currents_data: {
        "currents" => [
          { "name" => "Drive", "score" => 7, "summary" => "You move when there is a clear target.", "signals" => ["You save actionable ideas quickly."] },
          { "name" => "Stability", "score" => 6, "summary" => "You prefer rhythms that hold under pressure.", "signals" => ["You repeat routines once they work."] },
          { "name" => "Connection", "score" => 5, "summary" => "You use conversation as a thinking tool.", "signals" => ["You clarify by talking through choices."] },
          { "name" => "Agency", "score" => 8, "summary" => "You like to make deliberate calls.", "signals" => ["You ask for implementation, not just advice."] },
          { "name" => "Reflection", "score" => 7, "summary" => "You revisit patterns after action.", "signals" => ["You compare ideas against prior experience."] },
          { "name" => "Expression", "score" => 6, "summary" => "You value clear articulation.", "signals" => ["You care about the exact framing of a concept."] },
          { "name" => "Resilience", "score" => 7, "summary" => "You keep iterating rather than freezing.", "signals" => ["You change direction without losing momentum."] },
          { "name" => "Curiosity", "score" => 9, "summary" => "You naturally expand the scope of inquiry.", "signals" => ["You connect product ideas to larger systems."] },
          { "name" => "Integration", "score" => 8, "summary" => "You want insights to accumulate over time.", "signals" => ["You prefer systems where each exploration adds up."] }
        ]
      },
      source_snapshot: { "user_profile" => { "goals" => ["clarity"] } },
      source_digest: "digest-1",
      source_updated_at: Time.current,
      generated_at: Time.current
    )

    sign_in_as(user)

    get self_understanding_report_path
    assert_response :success
    assert_select "h2", text: "Pattern Snapshot"
    assert_select "h3", text: "Curiosity"
    assert_includes response.body, "You are balancing curiosity with steadiness."
    assert_includes response.body, "Loosely echoes Type 7"
  end
end
