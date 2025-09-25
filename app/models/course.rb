class Course < ApplicationRecord
  has_many :holes, dependent: :destroy
  # Normalize attributes before validation to make duplicate checks robust
  before_validation :normalize_attributes

  validates :name, presence: true
  validates :location, presence: true
  validates :name, uniqueness: { scope: :location, case_sensitive: false }

  private

  def normalize_attributes
    self.name = name.to_s.strip
    self.location = location.to_s.strip
  end
end


