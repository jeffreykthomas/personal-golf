class HoleImage < ApplicationRecord
  belongs_to :hole
  belongs_to :user
  belongs_to :source_image, class_name: 'HoleImage', optional: true
  has_many :derived_images, class_name: 'HoleImage', foreign_key: :source_image_id, dependent: :destroy
  has_many :hole_image_votes, dependent: :destroy

  has_one_attached :image

  enum :kind, { original: 'original', stylized: 'stylized' }
  enum :status, { pending: 'pending', processing: 'processing', ready: 'ready', failed: 'failed' }

  after_destroy_commit :purge_image_attachment

  # Turbo Stream broadcasts for live media grid updates
  after_create_commit :broadcast_placeholder
  after_update_commit :broadcast_tile_update
  after_update_commit :clear_processing_notice_when_ready

  def score
    total = upvotes_count + downvotes_count
    return 0.5 if total.zero?
    upvotes_count.to_f / total
  end

  private
    def purge_image_attachment
      image.purge_later if image.attached?
    end

    def stream_channel
      "hole_#{hole_id}_images"
    end

    def broadcast_placeholder
      # Only broadcast placeholders for original uploads (not derived stylized images)
      return if source_image_id.present?
      broadcast_prepend_later_to stream_channel,
        target: 'hole_images_grid',
        partial: 'hole_images/tile',
        locals: { image: self }
    end

    def broadcast_tile_update
      broadcast_replace_later_to stream_channel,
        partial: 'hole_images/tile',
        locals: { image: self }
    end

    def clear_processing_notice_when_ready
      return unless saved_change_to_status? && ready?
      broadcast_replace_later_to "hole_#{hole_id}_flash",
        target: 'hole_flash',
        html: ''
    end
end


