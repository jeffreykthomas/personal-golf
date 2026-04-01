class Tip < ApplicationRecord
  belongs_to :user
  belongs_to :category, optional: true
  belongs_to :course, optional: true
  has_many :saved_tips, dependent: :destroy
  has_many :saved_by_users, through: :saved_tips, source: :user
  has_many :dismissed_tips, dependent: :destroy
  has_many :dismissed_by_users, through: :dismissed_tips, source: :user

  validates :title, presence: true, length: { minimum: 5, maximum: 100 }
  validates :content, length: { minimum: 10, maximum: 1000 }, allow_blank: true
  validates :youtube_url, format: { with: /\A(https?:\/\/)?(www\.)?(youtube\.com\/watch\?v=|youtu\.be\/)[a-zA-Z0-9_-]{11}(\?.*)?\z/, allow_blank: true }
  validates :hole_number, numericality: { only_integer: true, greater_than: 0, less_than: 19 }, allow_nil: true

  enum :phase, { pre_round: 0, during_round: 1, post_round: 2 }
  enum :skill_level, { beginner: 0, intermediate: 1, advanced: 2 }
  enum :source, { user: 0, agent: 1, coach: 2 }

  scope :published, -> { where(published: true) }
  scope :by_category, ->(category) { where(category: category) }
  scope :for_skill_level, ->(level) { where(skill_level: level) }
  scope :popular, -> { order(save_count: :desc) }
  scope :recent, -> { order(created_at: :desc) }
  scope :insights, -> { where(type: "Insight") }
  scope :golf_tips, -> { where(type: [nil, "GolfTip"]) }
  scope :by_tag, lambda { |tag|
    normalized = tag.to_s.strip.downcase.tr(" ", "_")
    if normalized.present?
      escaped = ActiveRecord::Base.sanitize_sql_like(normalized)
      where("tags LIKE ?", "%\"#{escaped}\"%")
    else
      all
    end
  }

  scope :order_by_phase, -> {
    order(Arel.sql("CASE WHEN phase IS NULL THEN 1 ELSE 0 END, phase ASC"))
  }
  scope :order_by_category_distance, -> {
    left_joins(:category).order(Arel.sql(<<~SQL.squish))
      CASE categories.slug
        WHEN 'mental-game' THEN 0
        WHEN 'putting' THEN 1
        WHEN 'short-game' THEN 2
        WHEN 'driving' THEN 3
        WHEN 'course-management' THEN 4
        WHEN 'basics' THEN 5
        WHEN 'practice' THEN 6
        ELSE 7
      END ASC
    SQL
  }

  after_create_commit :broadcast_new_tip

  # Tags helpers
  def tags
    raw = read_attribute(:tags)
    return [] if raw.blank?
    parsed = (JSON.parse(raw) rescue nil)
    list = parsed.is_a?(Array) ? parsed : raw.to_s.split(',')
    normalize_tags(list)
  end

  def tags=(value)
    list = case value
           when String
             begin
               parsed = JSON.parse(value)
               parsed.is_a?(Array) ? parsed : value.split(',')
             rescue JSON::ParserError
               value.split(',')
             end
           when Array
             value
           else
             []
           end
    write_attribute(:tags, normalize_tags(list).to_json)
  end

  def self.allowed_tags
    []
  end

  def human_tags
    tags.map { |t| t.tr('_', ' ') }
  end

  def increment_save_count!
    increment!(:save_count)
  end

  def relevance_score
    # Simple algorithm that can be enhanced later
    base_score = 100
    age_penalty = (Date.current - created_at.to_date).to_i * 0.5
    popularity_bonus = save_count * 2
    ai_penalty = ai_generated? ? 10 : 0

    base_score - age_penalty + popularity_bonus - ai_penalty
  end

  def youtube_video_id
    return nil unless youtube_url.present?
    
    # Extract video ID from various YouTube URL formats
    patterns = [
      /(?:youtube\.com\/watch\?v=|youtu\.be\/)([a-zA-Z0-9_-]{11})/,
      /youtube\.com\/embed\/([a-zA-Z0-9_-]{11})/,
      /youtube\.com\/v\/([a-zA-Z0-9_-]{11})/
    ]
    
    patterns.each do |pattern|
      match = youtube_url.match(pattern)
      return match[1] if match
    end
    
    nil
  end

  def youtube_thumbnail_url
    video_id = youtube_video_id
    return nil unless video_id
    
    "https://img.youtube.com/vi/#{video_id}/maxresdefault.jpg"
  end

  def has_youtube_video?
    youtube_video_id.present?
  end

  private

  def normalize_tags(list)
    Array(list).map { |t| t.to_s.strip.downcase.tr(' ', '_') }.uniq
  end

  def broadcast_new_tip
    # Broadcast via Turbo Streams when implemented
    # broadcast_append_to "tips"
  end
end
