class CoachTipActionService
  class TipActionError < StandardError; end

  def initialize(user:, coach_session:)
    @user = user
    @coach_session = coach_session
  end

  def recommend_tip!(attributes)
    payload = attributes.is_a?(Hash) ? attributes : {}
    title = payload["title"].presence || payload[:title].presence || "Personalized coach tip"
    content = payload["content"].presence || payload[:content].presence
    raise TipActionError, "tip content is required" if content.blank?

    tip = find_duplicate_tip(title: title, content: content) || build_tip(title: title, content: content, payload: payload)
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

  def build_tip(title:, content:, payload:)
    category = resolve_category(payload)
    phase = resolve_phase(payload)
    skill_level = resolve_skill_level(payload)
    author = User.find_by(email_address: "system@personalgolf.app") || @user

    Tip.create!(
      title: title,
      content: content,
      user: author,
      category: category,
      phase: phase,
      skill_level: skill_level,
      ai_generated: true,
      published: true,
      course_id: payload["course_id"] || payload[:course_id],
      hole_number: payload["hole_number"] || payload[:hole_number]
    )
  end

  def find_duplicate_tip(title:, content:)
    Tip.published
       .where("lower(title) = ?", title.downcase)
       .where("substr(content, 1, 120) = ?", content.to_s[0...120])
       .where("created_at >= ?", 24.hours.ago)
       .first
  end

  def resolve_category(payload)
    slug = payload["category_slug"] || payload[:category_slug]
    category_id = payload["category_id"] || payload[:category_id]

    Category.find_by(id: category_id) ||
      Category.find_by(slug: slug) ||
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
