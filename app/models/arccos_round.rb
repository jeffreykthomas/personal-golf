class ArccosRound < ApplicationRecord
  belongs_to :user

  attribute :raw_payload, :json, default: {}

  validates :played_on, :course_name, :holes_played, presence: true
  validates :holes_played, numericality: { greater_than: 0, less_than_or_equal_to: 36 }

  scope :recent_first, -> { order(played_on: :desc, id: :desc) }
  scope :full_rounds, -> { where(holes_played: 18..) }
  scope :nine_hole, -> { where(holes_played: ...18) }
  scope :at_course, ->(name) { where("LOWER(course_name) = ?", name.to_s.downcase) }

  def nine_hole?
    holes_played < 18
  end

  def putts_per_18
    return nil if putts.nil? || holes_played.to_i.zero?

    (putts.to_f * 18.0 / holes_played).round(2)
  end

  def sg_putting_per_18
    return nil if sg_putting.nil? || holes_played.to_i.zero?

    (sg_putting.to_f * 18.0 / holes_played).round(3)
  end
end
