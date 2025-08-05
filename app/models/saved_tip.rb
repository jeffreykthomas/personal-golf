class SavedTip < ApplicationRecord
  belongs_to :user
  belongs_to :tip, counter_cache: :save_count

  validates :user_id, uniqueness: { scope: :tip_id }

  after_create_commit :increment_tip_save_count

  private

  def increment_tip_save_count
    tip.increment_save_count!
  end
end
