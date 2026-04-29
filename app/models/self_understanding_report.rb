class SelfUnderstandingReport < ApplicationRecord
  FRAMEWORK_NAME = "Nine Currents".freeze
  CURRENT_ORDER = NineCurrents.names.freeze

  belongs_to :user

  attribute :currents_data, :json, default: {}
  attribute :source_snapshot, :json, default: {}

  validates :framework_name, presence: true
  validates :title, presence: true
  validates :body_markdown, presence: true
  validates :source_digest, presence: true
  validates :generated_at, presence: true

  scope :latest_first, -> { order(generated_at: :desc, created_at: :desc) }

  def currents
    Array(currents_data.fetch("currents", currents_data[:currents]))
  end

  def ordered_currents
    indexed = currents.index_by { |current| current["name"] || current[:name] }
    CURRENT_ORDER.filter_map { |name| indexed[name] }
  end

  def current_definition(name)
    NineCurrents.definition_for(name)
  end
end
