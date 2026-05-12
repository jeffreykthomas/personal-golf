class PersonaQuestionService
  PERSONA_KEY = "persona".freeze
  COOLDOWN_SECONDS = 90
  RECENT_LOOKBACK = 6
  SKIP_RESURFACE_AFTER = 14.days

  def initialize(user:, coach_session: nil, now: Time.current)
    @user = user
    @coach_session = coach_session
    @now = now
  end

  def next_slot
    PersonaInventory::SLOTS.find { |slot| missing_or_stale?(slot) }
  end

  def next_prompt_payload
    PersonaInventory.slot_payload(next_slot)
  end

  def should_offer_inline_question?
    return false unless eligible_user?
    return false if next_slot.nil?
    return false if recent_persona_prompt?

    true
  end

  def persona_data
    coach_profile&.profile_data&.dig(PERSONA_KEY) || {}
  end

  def record_skip!(slot_key)
    slot = PersonaInventory.find(slot_key)
    return unless slot

    profile = ensure_coach_profile
    persona = (profile.profile_data || {}).deep_dup
    persona[PERSONA_KEY] ||= {}
    entry = persona[PERSONA_KEY][slot.key] || {}
    entry["skipped_at"] = @now.iso8601
    entry["skip_count"] = (entry["skip_count"] || 0) + 1
    persona[PERSONA_KEY][slot.key] = entry
    profile.profile_data = persona
    profile.learned_facts_count = persona.keys.count
    profile.last_synced_at = @now
    profile.save!
  end

  def record_answer!(slot_key, value:, freeform: nil)
    slot = PersonaInventory.find(slot_key)
    return unless slot

    profile = ensure_coach_profile
    persona = (profile.profile_data || {}).deep_dup
    persona[PERSONA_KEY] ||= {}

    normalized_value = normalize_value(slot, value)
    entry = persona[PERSONA_KEY][slot.key] || {}
    entry["value"] = normalized_value if normalized_value.present? || normalized_value.is_a?(Array)
    entry["freeform"] = freeform.to_s.strip if freeform.present?
    entry["updated_at"] = @now.iso8601
    entry.delete("skipped_at")

    persona[PERSONA_KEY][slot.key] = entry
    profile.profile_data = persona
    profile.learned_facts_count = persona.keys.count
    profile.last_synced_at = @now
    profile.save!

    persona[PERSONA_KEY][slot.key]
  end

  def slot_summary_text(slot_key)
    slot = PersonaInventory.find(slot_key)
    return nil unless slot

    entry = persona_data[slot.key] || {}
    value = entry["value"]
    freeform = entry["freeform"].to_s.strip
    parts = []

    if value.is_a?(Array) && value.any?
      parts << value.join(", ")
    elsif value.is_a?(String) && value.present?
      parts << value
    end

    parts << freeform if freeform.present?
    parts.join(" — ").presence
  end

  private

  def eligible_user?
    @user.present? && @user.respond_to?(:life?) && @user.life?
  end

  def missing_or_stale?(slot)
    entry = persona_data[slot.key]
    return true if entry.blank?
    return false if has_answer?(entry)

    skipped_at = entry["skipped_at"]
    return true unless skipped_at

    parsed = parse_time(skipped_at)
    return true unless parsed

    parsed < @now - SKIP_RESURFACE_AFTER
  end

  def has_answer?(entry)
    return false unless entry.is_a?(Hash)

    value = entry["value"]
    case value
    when Array
      value.any? { |v| v.to_s.strip.present? }
    when String
      value.strip.present?
    else
      false
    end
  end

  def recent_persona_prompt?
    return false unless @coach_session

    recent = @coach_session.coach_messages
                           .assistant
                           .order(created_at: :desc)
                           .limit(RECENT_LOOKBACK)

    recent.any? do |message|
      prompt = message.metadata.is_a?(Hash) ? message.metadata["prompt"] : nil
      next false unless prompt.is_a?(Hash) && prompt["kind"] == "persona_question"

      created = message.created_at || @now
      created > @now - COOLDOWN_SECONDS.seconds
    end
  end

  def normalize_value(slot, raw)
    if slot.multi_select
      values = Array(raw).flat_map { |item| item.to_s.split(",") }
                        .map { |item| item.to_s.strip }
                        .reject(&:blank?)
      values.uniq.first(slot.max_options || 8)
    else
      Array(raw).map(&:to_s).map(&:strip).reject(&:blank?).first
    end
  end

  def parse_time(raw)
    Time.iso8601(raw.to_s)
  rescue ArgumentError
    nil
  end

  def coach_profile
    @user&.coach_profile
  end

  def ensure_coach_profile
    @user.coach_profile || @user.create_coach_profile!
  end
end
