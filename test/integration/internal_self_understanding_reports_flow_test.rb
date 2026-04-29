require "test_helper"

class InternalSelfUnderstandingReportsFlowTest < ActionDispatch::IntegrationTest
  test "pending returns eligible report tasks" do
    user = create_user(app_mode: :life, goals: ["build more clarity"])
    user.create_coach_profile!(profile_data: { reflection_style: "thoughtful" })

    with_bridge_token do |token|
      get pending_internal_self_understanding_reports_path,
          headers: { "Authorization" => "Bearer #{token}" }
    end

    assert_response :success

    body = JSON.parse(response.body)
    task = body.fetch("tasks").first

    assert_equal user.id, task["user_id"]
    assert_equal "Nine Currents", task["framework_name"]
    assert_equal SelfUnderstandingReport::CURRENT_ORDER, task["current_order"]
    assert_equal 9, task["current_definitions"].size
    assert_match("Self-Understanding Report", task["prompt"])
    assert_match("Current definitions:", task["prompt"])
    assert_match("Loosely echoes Type", task["prompt"])
    assert task["source_digest"].present?
  end

  test "create persists a generated report for the matching digest" do
    user = create_user(app_mode: :life, goals: ["build more clarity"])
    user.create_coach_profile!(profile_data: { reflection_style: "thoughtful" })
    evaluation = SelfUnderstandingReportEligibilityService.new(user: user).evaluate

    with_bridge_token do |token|
      assert_difference -> { user.self_understanding_reports.count }, +1 do
        post internal_self_understanding_reports_path,
             params: {
               user_id: user.id,
               source_digest: evaluation.source_digest,
               report: generated_report_payload
             },
             as: :json,
             headers: { "Authorization" => "Bearer #{token}" }
      end
    end

    assert_response :created

    report = user.reload.latest_self_understanding_report
    assert_equal "Pattern Snapshot", report.title
    assert_equal evaluation.source_digest, report.source_digest
    assert_equal 9, report.currents.size
  end

  test "create rejects stale source digests" do
    user = create_user(app_mode: :life, goals: ["build more clarity"])
    user.create_coach_profile!(profile_data: { reflection_style: "thoughtful" })

    with_bridge_token do |token|
      assert_no_difference -> { user.self_understanding_reports.count } do
        post internal_self_understanding_reports_path,
             params: {
               user_id: user.id,
               source_digest: "stale-digest",
               report: generated_report_payload
             },
             as: :json,
             headers: { "Authorization" => "Bearer #{token}" }
      end
    end

    assert_response :conflict
    assert_equal "stale", JSON.parse(response.body).fetch("status")
  end

  private

  def generated_report_payload
    {
      title: "Pattern Snapshot",
      body_markdown: "## Overall pattern\n\nThis is a grounded synthesis.",
      currents: SelfUnderstandingReport::CURRENT_ORDER.map do |name|
        {
          name: name,
          score: 6,
          summary: "#{name} is moderately active right now.",
          signals: ["Observed through recent user behavior."]
        }
      end
    }
  end

  def with_bridge_token(token = "test-claw-token")
    previous = ENV["CLAW_SIBLING_TOKEN"]
    ENV["CLAW_SIBLING_TOKEN"] = token
    yield token
  ensure
    ENV["CLAW_SIBLING_TOKEN"] = previous
  end
end
