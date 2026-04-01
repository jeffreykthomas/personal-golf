class CoachTipActionService
  class TipActionError < StandardError; end

  INSIGHT_CATEGORY_DEFAULTS = {
    "preferences" => "Preferences",
    "strengths" => "Strengths",
    "goals" => "Goals",
    "health-wellness" => "Health & Wellness",
    "lifestyle" => "Lifestyle",
    "memories" => "Memories"
  }.freeze

  def initialize(user:, coach_session:)
    @user = user
    @coach_session = coach_session
  end

  def recommend_tip!(attributes)
    payload = attributes.is_a?(Hash) ? attributes : {}
    title = payload["title"].presence || payload[:title].presence || "Personalized coach tip"
    content = payload["content"].presence || payload[:content].presence
    raise TipActionError, "tip content is required" if content.blank?

    tip_class = resolve_tip_class(payload)
    tip = find_duplicate_tip(title: title, content: content, tip_class: tip_class) ||
      build_tip(title: title, content: content, payload: payload, tip_class: tip_class)
    @user.save_tip(tip) if auto_save_tip?(payload, tip_class)
    store_last_tip_id!(tip.id)
    tip
  end

  def save_tip!(tip_id: nil)
    tip = fetch_tip!(tip_id || last_tip_id)
    @user.save_tip(tip)
    tip
  end

  def dismiss_tip!(tip_id: nil)
    tip = fetch_tip!(tip_id || last_tip_id)
    @user.dismiss_tip(tip)
    tip
  end

  private

  def build_tip(title:, content:, payload:, tip_class:)
    category = resolve_category(payload, tip_class: tip_class)
    author = User.find_by(email_address: "system@personalgolf.app") || @user

    attrs = {
      title: title,
      content: content,
      user: author,
      category: category,
      tags: normalize_tags(payload),
      source: resolve_source(payload, tip_class),
      ai_generated: true,
      published: true
    }

    if tip_class == GolfTip
      attrs[:phase] = resolve_phase(payload)
      attrs[:skill_level] = resolve_skill_level(payload)
      attrs[:course_id] = payload["course_id"] || payload[:course_id]
      attrs[:hole_number] = payload["hole_number"] || payload[:hole_number]
    end

    tip_class.create!(attrs)
  end

  def find_duplicate_tip(title:, content:, tip_class:)
    scope = tip_class.published
                     .where("lower(title) = ?", title.downcase)
                     .where("substr(content, 1, 120) = ?", content.to_s[0...120])
                     .where("created_at >= ?", 24.hours.ago)

    return scope.first unless tip_class == Insight

    scope.where(id: @user.saved_tip_items.insights.select(:id)).first
  end

  def resolve_tip_class(payload)
    raw = payload["type"] || payload[:type] || payload["entry_type"] || payload[:entry_type]
    raw.to_s == "Insight" || raw.to_s.downcase == "insight" ? Insight : GolfTip
  end

  def resolve_category(payload, tip_class:)
    slug = payload["category_slug"] || payload[:category_slug]
    category_id = payload["category_id"] || payload[:category_id]

    category = Category.find_by(id: category_id) ||
      find_or_create_insight_category(slug, tip_class)
    return category if category.present?
    return nil if tip_class == Insight

    Category.find_by(slug: "basics") ||
      Category.first ||
      raise(TipActionError, "no category available for tip recommendation")
  end

  def resolve_phase(payload)
    phase = (payload["phase"] || payload[:phase]).to_s
    Tip.phases.key?(phase) ? phase : "during_round"
  end

  def resolve_skill_level(payload)
    level = (payload["skill_level"] || payload[:skill_level]).to_s
    return level if Tip.skill_levels.key?(level)
    return @user.skill_level if @user.skill_level.present?

    "beginner"
  end

  def resolve_source(payload, tip_class)
    source = (payload["source"] || payload[:source]).to_s
    return source if Tip.sources.key?(source)

    tip_class == Insight ? "agent" : "coach"
  end

  def normalize_tags(payload)
    tags = payload["tags"] || payload[:tags]
    case tags
    when String
      parsed = JSON.parse(tags) rescue tags.split(",")
      Array(parsed).map { |tag| tag.to_s.strip.downcase.tr(" ", "_") }.reject(&:blank?).uniq
    when Array
      tags.map { |tag| tag.to_s.strip.downcase.tr(" ", "_") }.reject(&:blank?).uniq
    else
      []
    end
  end

  def auto_save_tip?(payload, tip_class)
    raw = payload["auto_save"]
    raw = payload[:auto_save] if raw.nil?
    return true if raw == true || raw.to_s == "true"
    return false if raw == false || raw.to_s == "false"

    tip_class == Insight
  end

  def find_or_create_insight_category(slug, tip_class)
    return Category.find_by(slug: slug) if slug.blank?
    return Category.find_by(slug: slug) unless tip_class == Insight

    name = INSIGHT_CATEGORY_DEFAULTS[slug.to_s]
    return Category.find_by(slug: slug) unless name

    Category.find_or_create_by!(slug: slug) do |category|
      category.name = name
      category.description = "#{name} insights for coaching"
    end
  end

  def fetch_tip!(tip_id)
    raise TipActionError, "tip reference is missing" if tip_id.blank?

    Tip.find(tip_id)
  rescue ActiveRecord::RecordNotFound
    raise TipActionError, "tip not found"
  end

  def last_tip_id
    @coach_session.context_data["last_recommended_tip_id"]
  end

  def store_last_tip_id!(tip_id)
    context = (@coach_session.context_data || {}).merge("last_recommended_tip_id" => tip_id)
    @coach_session.update!(context_data: context)
  end
end
