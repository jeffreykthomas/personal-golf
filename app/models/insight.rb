class Insight < Tip
  after_initialize :set_default_source, if: :new_record?
  before_validation :set_default_source

  private

  def set_default_source
    self.source = :agent if source.blank? || source == "user"
  end
end
