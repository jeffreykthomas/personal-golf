class HoleTee < ApplicationRecord
  belongs_to :hole

  before_validation :normalize

  validates :name, presence: true
  validates :yardage, presence: true, numericality: { only_integer: true, greater_than: 50, less_than: 800 }
  validates :name, uniqueness: { scope: :hole_id, case_sensitive: false }

  private

  def normalize
    self.name = name.to_s.strip
  end
end


