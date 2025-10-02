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
                         .joins(image_attachment: :blob)
                         .where("active_storage_blobs.content_type LIKE ?", "image/%")
                         .includes(image_attachment: :blob)
    
    images = if stylized.exists?
               stylized
             else
               hole_images.ready
                         .joins(image_attachment: :blob)
                         .where("active_storage_blobs.content_type LIKE ?", "image/%")
                         .includes(image_attachment: :blob)
             end
    
    return nil if images.empty?
    
    # Weighted random by score (default 0.5)
    images_array = images.to_a
    weights = images_array.map { |img| [img, [img.score, 0.05].max] }
    total = weights.sum { |(_, w)| w }
    pick = rand * total
    weights.each do |img, w|
      return img if (pick -= w) <= 0
    end
    images_array.first
  end

  def images_for_display
    # Prefer stylized images, but check efficiently
    stylized_count = hole_images.ready.stylized
                                .joins(image_attachment: :blob)
                                .where("active_storage_blobs.content_type LIKE ?", "image/%")
                                .limit(1).count
    
    if stylized_count > 0
      hole_images.ready.stylized
                .joins(image_attachment: :blob)
                .where("active_storage_blobs.content_type LIKE ?", "image/%")
                .includes(image_attachment: :blob)
                .order(created_at: :desc)
    else
      hole_images.ready
                .joins(image_attachment: :blob)
                .where("active_storage_blobs.content_type LIKE ?", "image/%")
                .includes(image_attachment: :blob)
                .order(created_at: :desc)
    end
  end
end


