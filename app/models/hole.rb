class Hole < ApplicationRecord
  belongs_to :course
  has_many :hole_tees, dependent: :destroy

  validates :number, presence: true, numericality: { only_integer: true, greater_than: 0, less_than: 19 }
  validates :par, numericality: { only_integer: true, greater_than: 2, less_than: 6 }, allow_nil: true
  validates :yardage, numericality: { only_integer: true, greater_than: 50, less_than: 800 }, allow_nil: true

  has_one_attached :layout_image
  has_one_attached :stylized_layout_image

  has_many :hole_images, dependent: :destroy

  def select_image_for_display
    # Prefer stylized images
    stylized = hole_images.ready.stylized
    if stylized.exists?
      images = stylized.includes(image_attachment: :blob)
    else
      images = hole_images.ready.includes(image_attachment: :blob)
    end
    # Only consider actual images (exclude videos)
    images = images.select { |img| img.image.attached? && img.image.blob&.content_type.to_s.start_with?("image/") }
    return nil if images.empty?
    # Weighted random by score (default 0.5)
    weights = images.map { |img, | [img, [img.score, 0.05].max] }
    total = weights.sum { |(_, w)| w }
    pick = rand * total
    weights.each do |img, w|
      return img if (pick -= w) <= 0
    end
    images.first
  end

  def images_for_display
    preferred = hole_images.ready.stylized
    scope = preferred.exists? ? preferred : hole_images.ready
    records = scope.includes(image_attachment: :blob).order(created_at: :desc)
    # Exclude videos for hero/image-swiper usage
    records.select { |img| img.image.attached? && img.image.blob&.content_type.to_s.start_with?("image/") }
  end
end


