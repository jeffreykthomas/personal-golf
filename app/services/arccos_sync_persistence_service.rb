require "digest"

class ArccosSyncPersistenceService
  Result = Struct.new(:profile, :rounds_inserted, :rounds_updated, :rounds_touched_external_ids, :source_digest, keyword_init: true)

  def initialize(user:, payload:)
    @user = user
    @payload = payload || {}
  end

  def call
    ArccosProfile.transaction do
      profile = upsert_profile
      inserted, updated, touched_ids = upsert_rounds
      digest = compute_source_digest
      profile.record_success!(source_digest: digest)

      Result.new(
        profile: profile.reload,
        rounds_inserted: inserted,
        rounds_updated: updated,
        rounds_touched_external_ids: touched_ids,
        source_digest: digest
      )
    end
  end

  private

  attr_reader :user, :payload

  def upsert_profile
    profile_data = payload["profile"].is_a?(Hash) ? payload["profile"] : {}
    profile = ArccosProfile.for(user)

    profile.assign_attributes(
      handicap_index: cast_float(profile_data["handicap_index"]),
      scoring_average: cast_float(profile_data["scoring_average"]),
      rounds_tracked: cast_int(profile_data["rounds_tracked"]),
      smart_distances: sanitize_hash(profile_data["smart_distances"]),
      aggregate_strokes_gained: sanitize_hash(profile_data["aggregate_strokes_gained"]),
      metadata: sanitize_hash(profile_data["metadata"]),
      last_sync_status: "running"
    )
    profile.save!
    profile
  end

  def upsert_rounds
    rounds = Array(payload["rounds"]).select { |entry| entry.is_a?(Hash) }
    inserted = 0
    updated = 0
    touched_ids = []

    rounds.each do |round_payload|
      record = find_or_initialize_round(round_payload)
      was_new = record.new_record?
      assign_round_attributes(record, round_payload)
      record.save!

      touched_ids << record.external_id if record.external_id.present?
      if was_new
        inserted += 1
      else
        updated += 1
      end
    end

    [inserted, updated, touched_ids]
  end

  def find_or_initialize_round(round_payload)
    external_id = round_payload["external_id"].to_s.strip.presence

    if external_id
      user.arccos_rounds.where(external_id: external_id).first_or_initialize
    else
      played_on = parse_date(round_payload["played_on"])
      course_name = round_payload["course_name"].to_s.strip
      scope = user.arccos_rounds.where(played_on: played_on, course_name: course_name, external_id: nil)
      scope.first || user.arccos_rounds.build
    end
  end

  def assign_round_attributes(record, round_payload)
    record.external_id = round_payload["external_id"].to_s.strip.presence
    record.played_on = parse_date(round_payload["played_on"])
    record.course_name = round_payload["course_name"].to_s.strip
    record.course_external_id = round_payload["course_external_id"].to_s.strip.presence
    record.holes_played = cast_int(round_payload["holes_played"]) || 18
    record.total_score = cast_int(round_payload["total_score"])
    record.total_par = cast_int(round_payload["total_par"])
    record.putts = cast_int(round_payload["putts"])
    record.greens_in_regulation = cast_int(round_payload["greens_in_regulation"])
    record.fairways_hit = cast_int(round_payload["fairways_hit"])
    record.fairways_attempted = cast_int(round_payload["fairways_attempted"])
    record.sg_total = cast_float(round_payload["sg_total"])
    record.sg_putting = cast_float(round_payload["sg_putting"])
    record.sg_short_game = cast_float(round_payload["sg_short_game"])
    record.sg_approach = cast_float(round_payload["sg_approach"])
    record.sg_off_tee = cast_float(round_payload["sg_off_tee"])
    record.raw_payload = sanitize_hash(round_payload)
  end

  def sanitize_hash(value)
    value.is_a?(Hash) ? value : {}
  end

  def cast_int(value)
    return nil if value.nil? || value.to_s.strip.empty?

    Integer(value)
  rescue ArgumentError, TypeError
    nil
  end

  def cast_float(value)
    return nil if value.nil? || value.to_s.strip.empty?

    Float(value)
  rescue ArgumentError, TypeError
    nil
  end

  def parse_date(value)
    return value if value.is_a?(Date)
    return nil if value.blank?

    Date.parse(value.to_s)
  rescue ArgumentError
    nil
  end

  def compute_source_digest
    Digest::SHA256.hexdigest(JSON.generate(sort_hash_deep(payload)))
  end

  def sort_hash_deep(value)
    case value
    when Hash
      value.sort.to_h.transform_values { |v| sort_hash_deep(v) }
    when Array
      value.map { |v| sort_hash_deep(v) }
    else
      value
    end
  end
end
