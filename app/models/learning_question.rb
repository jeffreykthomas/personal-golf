class LearningQuestion < ApplicationRecord
  belongs_to :learning_node

  attribute :citations_data, :json, default: []
  attribute :metadata, :json, default: {}

  enum :status, { pending: 0, answered: 1, failed: 2 }

  validates :question_text, presence: true

  after_commit :broadcast_learning_workspace_refresh

  private

  def broadcast_learning_workspace_refresh
    return unless learning_node&.user.present?

    broadcast_refresh_later_to(learning_node.user.learning_workspace_stream_name)
  end
end
