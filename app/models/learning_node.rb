require "digest"

class LearningNode < ApplicationRecord
  MAX_CHILDREN_PER_LEVEL = 5

  belongs_to :user
  belongs_to :parent, class_name: "LearningNode", optional: true
  has_many :children, -> { order(:position, :title) }, class_name: "LearningNode", foreign_key: :parent_id, dependent: :destroy, inverse_of: :parent
  has_many :learning_sources, dependent: :destroy
  has_many :learning_questions, dependent: :destroy
  has_many :outgoing_learning_node_links, class_name: "LearningNodeLink", foreign_key: :from_node_id, dependent: :destroy, inverse_of: :from_node
  has_many :incoming_learning_node_links, class_name: "LearningNodeLink", foreign_key: :to_node_id, dependent: :destroy, inverse_of: :to_node

  attribute :metadata, :json, default: {}

  enum :node_kind, { topic: 0, cluster: 1, generated_note: 2 }
  enum :status, { draft: 0, pending_research: 1, ready: 2, rebalancing: 3, archived: 4 }

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: { scope: :user_id }

  scope :roots, -> { where(parent_id: nil).order(:position, :title) }

  before_validation :ensure_defaults
  before_validation :assign_slug, if: :should_assign_slug?
  after_commit :sync_wikilinks!, if: :should_sync_wikilinks?
  after_commit :broadcast_learning_workspace_refresh

  def ordered_children
    children.order(:position, :title)
  end

  def breadcrumbs
    node = self
    trail = []

    while node
      trail.unshift(node)
      node = node.parent
    end

    trail
  end

  def explicit_and_backlinked_nodes
    LearningNode.where(id: explicit_related_nodes.select(:id)).or(
      LearningNode.where(id: backlinked_nodes.select(:id))
    ).where.not(id: id).distinct.order(:title)
  end

  def explicit_related_nodes
    LearningNode.where(id: outgoing_learning_node_links.related.select(:to_node_id)).order(:title)
  end

  def backlinked_nodes
    LearningNode.where(id: incoming_learning_node_links.select(:from_node_id)).where.not(id: id).distinct.order(:title)
  end

  def local_graph_nodes
    LearningNode.where(id: [parent_id, ordered_children.pluck(:id), explicit_and_backlinked_nodes.pluck(:id)].flatten.compact).order(:title)
  end

  def wikilink_titles
    body_markdown.to_s.scan(/\[\[([^\]]+)\]\]/).flatten.map(&:strip).reject(&:blank?).uniq
  end

  def sync_wikilinks!
    outgoing_learning_node_links.wikilink.delete_all
    return if wikilink_titles.empty?

    targets = user.learning_nodes
                  .where.not(id: id)
                  .where("LOWER(title) IN (?) OR LOWER(slug) IN (?)", wikilink_titles.map(&:downcase), wikilink_titles.map { |title| title.parameterize })

    targets.find_each do |target|
      outgoing_learning_node_links.find_or_create_by!(to_node: target, relation_kind: :wikilink)
    end
  end

  def compiled_source_snapshot
    {
      title: title,
      summary: summary,
      sources: learning_sources.order(:created_at).map do |source|
        {
          id: source.id,
          title: source.title,
          url: source.url,
          quality_score: source.quality_score,
          extraction_status: source.extraction_status,
          summary_markdown: source.summary_markdown,
          content_hash: source.content_hash
        }
      end,
      questions: learning_questions.order(:created_at).map do |question|
        {
          id: question.id,
          question_text: question.question_text,
          answer_markdown: question.answer_markdown,
          answered_at: question.answered_at&.iso8601
        }
      end,
      children: ordered_children.map do |child|
        {
          id: child.id,
          title: child.title,
          summary: child.summary
        }
      end
    }
  end

  def compiled_source_digest
    Digest::SHA256.hexdigest(JSON.generate(compiled_source_snapshot))
  end

  def needs_compilation?
    metadata.fetch("compiled_source_digest", nil) != compiled_source_digest || body_markdown.blank?
  end

  def crowded?
    ordered_children.count > MAX_CHILDREN_PER_LEVEL
  end

  private

  def ensure_defaults
    self.metadata ||= {}
  end

  def should_assign_slug?
    slug.blank? || will_save_change_to_title?
  end

  def assign_slug
    base = title.to_s.parameterize.presence || "node"
    candidate = base
    suffix = 2

    while user&.learning_nodes&.where.not(id: id)&.exists?(slug: candidate)
      candidate = "#{base}-#{suffix}"
      suffix += 1
    end

    self.slug = candidate
  end

  def should_sync_wikilinks?
    previous_changes.key?("body_markdown") || previous_changes.key?("title")
  end

  def broadcast_learning_workspace_refresh
    return unless user.present?

    broadcast_refresh_later_to(user.learning_workspace_stream_name)
  end
end
