class Category < ApplicationRecord
  has_many :tips, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true

  before_validation :generate_slug, if: :name_changed?

  scope :with_tips, -> { joins(:tips).distinct }

  private

  def generate_slug
    self.slug = name.parameterize if name.present?
  end
end
