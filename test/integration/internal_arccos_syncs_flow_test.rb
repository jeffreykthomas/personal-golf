require "test_helper"

class InternalArccosSyncsFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user
    @token = "test-token"
    ENV["CLAW_SIBLING_TOKEN"] = @token
  end

  teardown do
    ENV.delete("CLAW_SIBLING_TOKEN")
  end

  def bridge_headers
    { "Authorization" => "Bearer #{@token}", "Content-Type" => "application/json" }
  end

  test "pending returns users with no profile or stale sync" do
    get pending_internal_arccos_syncs_path, params: { user_id: @user.id }, headers: bridge_headers

    assert_response :success
    tasks = response.parsed_body["tasks"]
    assert_equal 1, tasks.length
    task = tasks.first
    assert_equal @user.id, task["user_id"]
    assert_equal "pending", task["last_sync_status"]
    assert_not_nil task["cutoff_date"]
    assert_equal [], task["known_external_ids"]
    assert_kind_of Integer, task["max_rounds"]
  end

  test "pending echoes known external_ids from existing rounds within cutoff" do
    @user.arccos_rounds.create!(
      external_id: "recent-1",
      played_on: 2.months.ago.to_date,
      course_name: "The Farms",
      holes_played: 18
    )
    @user.arccos_rounds.create!(
      external_id: "ancient-1",
      played_on: 2.years.ago.to_date,
      course_name: "Old Course",
      holes_played: 18
    )

    get pending_internal_arccos_syncs_path,
        params: { user_id: @user.id, cutoff_months: 6 },
        headers: bridge_headers

    task = response.parsed_body["tasks"].first
    assert_includes task["known_external_ids"], "recent-1"
    assert_not_includes task["known_external_ids"], "ancient-1"
  end

  test "pending skips users with a fresh successful sync unless forced" do
    profile = ArccosProfile.for(@user)
    profile.save!
    profile.record_success!(source_digest: "abc", synced_at: 1.hour.ago)

    get pending_internal_arccos_syncs_path, params: { user_id: @user.id }, headers: bridge_headers
    assert_equal 0, response.parsed_body["tasks"].length

    get pending_internal_arccos_syncs_path, params: { user_id: @user.id, force: true }, headers: bridge_headers
    assert_equal 1, response.parsed_body["tasks"].length
  end

  test "start marks profile as running" do
    post start_internal_arccos_syncs_path,
         params: { user_id: @user.id }.to_json,
         headers: bridge_headers

    assert_response :success
    assert_equal "running", ArccosProfile.for(@user).last_sync_status
  end

  test "create accepts 'payload' key (bridge format)" do
    body = {
      user_id: @user.id,
      payload: {
        profile: { handicap_index: 9.0 },
        rounds: [{ played_on: "2026-04-01", course_name: "X", holes_played: 18, total_score: 82 }]
      }
    }
    post internal_arccos_syncs_path, params: body.to_json, headers: bridge_headers
    assert_response :success
    assert_equal 1, @user.reload.arccos_rounds.count
  end

  test "create persists profile and rounds" do
    payload = {
      user_id: @user.id,
      sync: {
        profile: { handicap_index: 10.5, rounds_tracked: 12 },
        rounds: [
          {
            external_id: "e-1",
            played_on: "2026-04-10",
            course_name: "The Farms",
            holes_played: 9,
            total_score: 45,
            putts: 16,
            sg_putting: -0.5
          }
        ]
      }
    }

    post internal_arccos_syncs_path, params: payload.to_json, headers: bridge_headers

    assert_response :success
    body = response.parsed_body
    assert_equal 1, body["rounds_inserted"]
    assert_equal "succeeded", body["profile"]["last_sync_status"]
    assert_equal 1, @user.reload.arccos_rounds.count
  end

  test "fail records the error message" do
    post fail_internal_arccos_syncs_path,
         params: { user_id: @user.id, message: "browser timeout" }.to_json,
         headers: bridge_headers

    assert_response :success
    profile = ArccosProfile.for(@user)
    assert_equal "failed", profile.last_sync_status
    assert_equal "browser timeout", profile.last_sync_error
  end

  test "rejects requests missing the bridge token" do
    get pending_internal_arccos_syncs_path
    assert_response :unauthorized
  end
end
