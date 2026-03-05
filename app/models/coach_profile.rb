class CoachProfile < ApplicationRecord
  belongs_to :user

  attribute :profile_data, :json, default: {}

  validates :user_id, uniqueness: true

  before_validation :ensure_defaults

  def merge_facts!(facts)
    return unless facts.is_a?(Hash)

    merged = (profile_data || {}).deep_merge(facts)
    self.profile_data = merged
    self.learned_facts_count = merged.keys.count
    self.last_synced_at = Time.current
    save!
  end

  private

  def ensure_defaults
    self.profile_data ||= {}
  end
end
