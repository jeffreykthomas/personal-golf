class ArccosProfile < ApplicationRecord
  belongs_to :user

  SYNC_STATUSES = %w[pending running succeeded failed].freeze

  attribute :smart_distances, :json, default: {}
  attribute :aggregate_strokes_gained, :json, default: {}
  attribute :metadata, :json, default: {}

  validates :last_sync_status, inclusion: { in: SYNC_STATUSES }

  def self.for(user)
    find_or_initialize_by(user_id: user.id)
  end

  def fresh?(within: 7.days)
    last_synced_at.present? && last_synced_at > within.ago
  end

  def record_success!(source_digest:, synced_at: Time.current)
    update!(
      last_sync_status: "succeeded",
      last_sync_source_digest: source_digest,
      last_synced_at: synced_at,
      last_sync_error: nil
    )
  end

  def record_failure!(message)
    update!(last_sync_status: "failed", last_sync_error: message.to_s.first(2000))
  end
end
