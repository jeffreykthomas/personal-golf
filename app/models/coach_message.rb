class CoachMessage < ApplicationRecord
  belongs_to :coach_session
  belongs_to :tip, optional: true

  enum :role, { user: 0, assistant: 1, system: 2, tool: 3 }
  enum :modality, { text: 0, voice: 1, event: 2 }

  attribute :metadata, :json, default: {}

  validates :content, presence: true
  validates :role, presence: true
  validates :modality, presence: true

  before_validation :ensure_defaults
  after_create_commit :touch_session_activity

  def as_payload
    {
      id: id,
      role: role,
      modality: modality,
      content: content,
      tip_id: tip_id,
      metadata: metadata || {},
      created_at: created_at&.iso8601
    }
  end

  private

  def ensure_defaults
    self.metadata ||= {}
  end

  def touch_session_activity
    coach_session.update_column(:last_activity_at, Time.current) # rubocop:disable Rails/SkipsModelValidations
  end
end
