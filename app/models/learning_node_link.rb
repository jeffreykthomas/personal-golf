class LearningNodeLink < ApplicationRecord
  belongs_to :from_node, class_name: "LearningNode", inverse_of: :outgoing_learning_node_links
  belongs_to :to_node, class_name: "LearningNode", inverse_of: :incoming_learning_node_links

  attribute :metadata, :json, default: {}

  enum :relation_kind, { related: 0, wikilink: 1, source_context: 2 }

  validates :to_node_id, uniqueness: { scope: [:from_node_id, :relation_kind] }
  validate :nodes_must_be_distinct
  validate :nodes_must_belong_to_same_user

  after_commit :broadcast_learning_workspace_refresh

  private

  def nodes_must_be_distinct
    return unless from_node_id.present? && from_node_id == to_node_id

    errors.add(:to_node_id, "must be different from from_node_id")
  end

  def nodes_must_belong_to_same_user
    return if from_node.blank? || to_node.blank?
    return if from_node.user_id == to_node.user_id

    errors.add(:to_node_id, "must belong to the same user")
  end

  def broadcast_learning_workspace_refresh
    return unless from_node&.user.present?

    broadcast_refresh_later_to(from_node.user.learning_workspace_stream_name)
  end
end
