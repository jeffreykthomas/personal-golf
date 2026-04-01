class GolfTip < Tip
  TAG_OPTIONS = %w[
    driver fairway_woods long_irons short_irons wedges putter
    full_shots punch_shots hook_shots slice_shots pitches chips flop_shots
    long_putts short_putts
    from_the_tee approach_shot around_the_green on_the_green
  ].freeze

  validates :category, presence: true
  validate :tags_are_allowed
  validate :course_tip_requires_hole_number
  validate :course_tip_requires_course

  def self.allowed_tags
    TAG_OPTIONS
  end

  private

  def tags_are_allowed
    invalid = tags - TAG_OPTIONS
    errors.add(:tags, "contain invalid entries: #{invalid.join(', ')}") if invalid.any?
  end

  def course_tip_requires_hole_number
    return unless category&.slug == "course-tip"

    errors.add(:hole_number, "is required for course tips") if hole_number.blank?
  end

  def course_tip_requires_course
    return unless category&.slug == "course-tip"

    errors.add(:course, "is required for course tips") if course.nil?
  end
end
