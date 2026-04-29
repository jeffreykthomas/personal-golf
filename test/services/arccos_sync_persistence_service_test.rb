require "test_helper"

class ArccosSyncPersistenceServiceTest < ActiveSupport::TestCase
  setup do
    @user = create_user
  end

  def sample_payload
    {
      "profile" => {
        "handicap_index" => 12.4,
        "scoring_average" => 88.3,
        "rounds_tracked" => 42,
        "smart_distances" => { "driver" => 242 },
        "aggregate_strokes_gained" => { "putting" => -0.4 },
        "metadata" => { "scraped_at" => "2026-04-18T08:00:00Z" }
      },
      "rounds" => [
        {
          "external_id" => "r-1001",
          "played_on" => "2026-04-10",
          "course_name" => "The Farms",
          "holes_played" => 9,
          "total_score" => 46,
          "total_par" => 36,
          "putts" => 17,
          "sg_putting" => -0.8,
          "sg_total" => -2.1
        },
        {
          "external_id" => "r-1002",
          "played_on" => "2026-04-05",
          "course_name" => "Mission Hills",
          "holes_played" => 18,
          "total_score" => 89,
          "total_par" => 72,
          "putts" => 32,
          "sg_putting" => 0.2,
          "sg_total" => -0.9
        }
      ]
    }
  end

  test "persists profile and rounds, marking sync successful" do
    result = ArccosSyncPersistenceService.new(user: @user, payload: sample_payload).call

    assert_equal 2, result.rounds_inserted
    assert_equal 0, result.rounds_updated
    assert_equal "succeeded", result.profile.last_sync_status
    assert_equal 12.4, result.profile.handicap_index
    assert_equal 42, result.profile.rounds_tracked
    assert_equal result.source_digest, result.profile.last_sync_source_digest
    assert result.profile.last_synced_at.present?

    farms = @user.arccos_rounds.find_by(external_id: "r-1001")
    assert_equal "The Farms", farms.course_name
    assert_equal 9, farms.holes_played
    assert farms.nine_hole?
    assert_in_delta(-1.6, farms.sg_putting_per_18, 0.01)
    assert_equal 34, farms.putts_per_18.round
  end

  test "upserts existing round by external_id without duplicating" do
    ArccosSyncPersistenceService.new(user: @user, payload: sample_payload).call

    updated_payload = sample_payload
    updated_payload["rounds"][0]["total_score"] = 45
    updated_payload["rounds"][0]["putts"] = 16

    result = ArccosSyncPersistenceService.new(user: @user, payload: updated_payload).call

    assert_equal 0, result.rounds_inserted
    assert_equal 2, result.rounds_updated
    assert_equal 2, @user.arccos_rounds.count

    farms = @user.arccos_rounds.find_by(external_id: "r-1001")
    assert_equal 45, farms.total_score
    assert_equal 16, farms.putts
  end

  test "falls back to played_on + course_name when external_id is missing" do
    payload = sample_payload
    payload["rounds"][0].delete("external_id")

    ArccosSyncPersistenceService.new(user: @user, payload: payload).call
    ArccosSyncPersistenceService.new(user: @user, payload: payload).call

    matching = @user.arccos_rounds.where(course_name: "The Farms", played_on: Date.parse("2026-04-10"))
    assert_equal 1, matching.count
  end
end
