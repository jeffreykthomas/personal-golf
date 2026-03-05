class CoachSession < ApplicationRecord
  belongs_to :user
  has_many :coach_messages, dependent: :destroy

  enum :phase, { onboarding: 0, pre_round: 1, during_round: 2, post_round: 3 }
  enum :status, { active: 0, completed: 1, archived: 2 }

  attribute :context_data, :json, default: {}

  validates :phase, presence: true
  validates :status, presence: true

  before_validation :ensure_defaults
  before_create :stamp_started_at

  scope :recent_first, -> { order(updated_at: :desc) }

  def append_context!(extra_context)
    return unless extra_context.is_a?(Hash)

    self.context_data = (context_data || {}).deep_merge(extra_context)
    self.last_activity_at = Time.current
    save!
  end

  def mark_completed!
    update!(status: :completed, ended_at: Time.current, last_activity_at: Time.current)
  end

  private

  def ensure_defaults
    self.context_data ||= {}
  end

  def stamp_started_at
    now = Time.current
    self.started_at ||= now
    self.last_activity_at ||= now
  end
end
