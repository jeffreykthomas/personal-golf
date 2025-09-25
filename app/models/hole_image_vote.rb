class HoleImageVote < ApplicationRecord
  belongs_to :hole_image, counter_cache: :upvotes_count, optional: true
  belongs_to :user

  validates :value, inclusion: { in: [-1, 1] }

  after_save :recount!

  private

  def recount!
    image = hole_image
    return unless image
    counts = image.hole_image_votes.group(:value).count
    image.update_columns(
      upvotes_count: counts[1].to_i,
      downvotes_count: counts[-1].to_i
    )
  end
end


