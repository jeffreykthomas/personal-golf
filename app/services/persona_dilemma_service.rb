class PersonaDilemmaService
  SIGNALS_KEY = "persona_signals".freeze
  HISTORY_KEY = "persona_dilemma_history".freeze
  HISTORY_LIMIT = 200
  RESURFACE_AFTER = 60.days

  def initialize(user:, coach_session: nil, now: Time.current)
    @user = user
    @coach_session = coach_session
    @now = now
  end

  def next_dilemma
    asked = recent_dilemma_ids
    available = PersonaDilemmaBank::DILEMMAS.reject { |d| asked.include?(d.id) }
    return nil if available.empty?

    available.max_by { |dilemma| score_dilemma(dilemma) }
  end

  def next_payload
    PersonaDilemmaBank.category_payload(next_dilemma)
  end

  def record_answer!(dilemma_id, option_id:, freeform: nil)
    dilemma = PersonaDilemmaBank.find(dilemma_id)
    return nil unless dilemma

    option = dilemma.options.find { |opt| opt.id == option_id.to_s }

    profile = ensure_coach_profile
    data = (profile.profile_data || {}).deep_dup
    data[SIGNALS_KEY] ||= {}
    data[HISTORY_KEY] ||= []

    if option
      apply_signals!(data[SIGNALS_KEY], option.signals)
    end

    entry = {
      "id" => dilemma.id,
      "category" => dilemma.category,
      "title" => dilemma.title,
      "option_id" => option&.id,
      "option_label" => option&.label,
      "freeform" => freeform.to_s.strip.presence,
      "answered_at" => @now.iso8601
    }
    data[HISTORY_KEY] = (data[HISTORY_KEY] + [ entry ]).last(HISTORY_LIMIT)

    profile.profile_data = data
    profile.last_synced_at = @now
    profile.learned_facts_count = computed_facts_count(data)
    profile.save!

    { dilemma: dilemma, option: option, entry: entry }
  end

  def record_skip!(dilemma_id)
    dilemma = PersonaDilemmaBank.find(dilemma_id)
    return nil unless dilemma

    profile = ensure_coach_profile
    data = (profile.profile_data || {}).deep_dup
    data[HISTORY_KEY] ||= []
    data[HISTORY_KEY] = (data[HISTORY_KEY] + [ {
      "id" => dilemma.id,
      "category" => dilemma.category,
      "title" => dilemma.title,
      "skipped_at" => @now.iso8601
    } ]).last(HISTORY_LIMIT)
    profile.profile_data = data
    profile.last_synced_at = @now
    profile.save!
    dilemma
  end

  def signals_data
    coach_profile&.profile_data&.dig(SIGNALS_KEY) || {}
  end

  def history
    coach_profile&.profile_data&.dig(HISTORY_KEY) || []
  end

  def trait_rankings(category)
    by_trait = signals_data[category.to_s] || {}
    by_trait.sort_by { |_trait, weight| -weight.to_f }.map { |trait, weight| [ trait, weight.to_f ] }
  end

  def top_traits(category, limit: 2)
    trait_rankings(category).first(limit)
  end

  def acknowledgement_for(dilemma:, option:)
    return nil unless dilemma && option

    primary_signals = primary_signals_from(option)
    return "Got it — that gives me something useful." if primary_signals.empty?

    pieces = primary_signals.map do |category, trait|
      humanize_trait_phrase(category: category, trait: trait)
    end.compact

    return "Got it — saved." if pieces.empty?

    "Got it — that suggests #{join_phrases(pieces)}. I'll keep watching for what nuances this."
  end

  private

  def recent_dilemma_ids
    history.map { |entry| entry["id"] }.compact
  end

  def score_dilemma(dilemma)
    base = 1.0
    coverage_bonus = dilemma.options.sum do |option|
      option.signals.sum do |category, traits|
        traits.sum do |trait, weight|
          existing = signals_data.dig(category, trait).to_f
          # higher score for under-represented traits
          (1.0 / (1.0 + existing)) * weight.to_f
        end
      end
    end
    category_bonus = category_underrepresentation_bonus(dilemma.category)

    base + coverage_bonus + category_bonus
  end

  def category_underrepresentation_bonus(category)
    by_category = PersonaDilemmaBank::CATEGORIES.map do |cat|
      [ cat, history.count { |entry| entry["category"] == cat } ]
    end.to_h

    min_count = by_category.values.min || 0
    count_for_this = by_category[category] || 0
    count_for_this == min_count ? 0.5 : 0.0
  end

  def primary_signals_from(option)
    pairs = []
    option.signals.each do |category, traits|
      next if traits.empty?

      top = traits.max_by { |_t, w| w.to_f }
      next unless top

      pairs << [ category, top.first ]
    end
    pairs.first(2)
  end

  def humanize_trait_phrase(category:, trait:)
    trait_text = trait.to_s.tr("_", " ")
    case category.to_s
    when "values"
      "you lean toward #{trait_text} when it pulls against other things"
    when "priorities"
      "your priority weight tilts toward #{trait_text} right now"
    when "beliefs"
      "you carry a belief that's closer to '#{trait_text}'"
    when "fears"
      "there's a real edge of #{trait_text} in the mix"
    when "strengths"
      "#{trait_text} is a natural strength of yours"
    when "weaknesses"
      "#{trait_text} is a slip you're aware of"
    when "preferences"
      "you prefer #{trait_text}"
    else
      trait_text
    end
  end

  def join_phrases(phrases)
    case phrases.length
    when 0 then ""
    when 1 then phrases.first
    when 2 then "#{phrases.first} and #{phrases.last}"
    else "#{phrases[0..-2].join(', ')}, and #{phrases.last}"
    end
  end

  def apply_signals!(target, signals)
    signals.each do |category, traits|
      target[category.to_s] ||= {}
      traits.each do |trait, weight|
        current = target[category.to_s][trait.to_s].to_f
        target[category.to_s][trait.to_s] = (current + weight.to_f).round(4)
      end
    end
  end

  def computed_facts_count(data)
    persona = data["persona"].is_a?(Hash) ? data["persona"].keys.count : 0
    signals = data[SIGNALS_KEY].is_a?(Hash) ? data[SIGNALS_KEY].sum { |_c, traits| traits.is_a?(Hash) ? traits.keys.count : 0 } : 0
    persona + signals
  end

  def coach_profile
    @user&.coach_profile
  end

  def ensure_coach_profile
    @user.coach_profile || @user.create_coach_profile!
  end
end
