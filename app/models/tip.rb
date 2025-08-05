class Tip < ApplicationRecord
  belongs_to :user
  belongs_to :category
  has_many :saved_tips, dependent: :destroy
  has_many :saved_by_users, through: :saved_tips, source: :user

  validates :title, presence: true, length: { minimum: 5, maximum: 100 }
  validates :content, presence: true, length: { minimum: 10, maximum: 1000 }

  enum :phase, { pre_round: 0, during_round: 1, post_round: 2 }
  enum :skill_level, { beginner: 0, intermediate: 1, advanced: 2 }

  scope :published, -> { where(published: true) }
  scope :by_category, ->(category) { where(category: category) }
  scope :for_skill_level, ->(level) { where(skill_level: level) }
  scope :popular, -> { order(save_count: :desc) }
  scope :recent, -> { order(created_at: :desc) }

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

  private

  def broadcast_new_tip
    # Broadcast via Turbo Streams when implemented
    # broadcast_append_to "tips"
  end
end
