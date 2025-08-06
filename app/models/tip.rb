class Tip < ApplicationRecord
  belongs_to :user
  belongs_to :category
  has_many :saved_tips, dependent: :destroy
  has_many :saved_by_users, through: :saved_tips, source: :user

  validates :title, presence: true, length: { minimum: 5, maximum: 100 }
  validates :content, presence: true, length: { minimum: 10, maximum: 1000 }
  validates :youtube_url, format: { with: /\A(https?:\/\/)?(www\.)?(youtube\.com\/watch\?v=|youtu\.be\/)[a-zA-Z0-9_-]{11}(\?.*)?\z/, allow_blank: true }

  enum :phase, { pre_round: 0, during_round: 1, post_round: 2 }
  enum :skill_level, { beginner: 0, intermediate: 1, advanced: 2 }

  scope :published, -> { where(published: true) }
  scope :by_category, ->(category) { where(category: category) }
  scope :for_skill_level, ->(level) { where(skill_level: level) }
  scope :popular, -> { order(save_count: :desc) }
  scope :recent, -> { order(created_at: :desc) }

  scope :order_by_phase, -> { order(phase: :asc) }
  scope :order_by_category_distance, -> {
    joins(:category).order(Arel.sql(<<~SQL.squish))
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

  def broadcast_new_tip
    # Broadcast via Turbo Streams when implemented
    # broadcast_append_to "tips"
  end
end
