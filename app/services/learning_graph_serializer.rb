class LearningGraphSerializer
  def initialize(user:)
    @user = user
  end

  def call
    {
      nodes: serialized_nodes,
      edges: serialized_edges
    }
  end

  private

  attr_reader :user

  def nodes
    @nodes ||= user.learning_nodes
                   .select(:id, :title, :slug, :status, :node_kind, :parent_id, :summary, :updated_at)
                   .to_a
  end

  def root_id_for
    @root_id_for ||= begin
      by_id = nodes.index_by(&:id)
      cache = {}

      resolve = lambda do |node|
        return cache[node.id] if cache.key?(node.id)

        current = node
        visited = Set.new

        while current.parent_id && (parent = by_id[current.parent_id]) && !visited.include?(current.id)
          visited << current.id
          current = parent
        end

        cache[node.id] = current.id
      end

      nodes.each_with_object({}) { |node, hash| hash[node.id] = resolve.call(node) }
    end
  end

  def source_counts
    @source_counts ||= LearningSource.where(learning_node_id: nodes.map(&:id)).group(:learning_node_id).count
  end

  def serialized_nodes
    nodes.map do |node|
      {
        id: node.id,
        title: node.title,
        slug: node.slug,
        status: node.status,
        kind: node.node_kind,
        parent_id: node.parent_id,
        is_root: node.parent_id.nil?,
        root_id: root_id_for[node.id],
        summary: node.summary.to_s.truncate(180, separator: " "),
        source_count: source_counts[node.id].to_i,
        updated_at: node.updated_at&.iso8601
      }
    end
  end

  def hierarchy_edges
    nodes.each_with_object([]) do |node, edges|
      next unless node.parent_id

      edges << {
        id: "h-#{node.parent_id}-#{node.id}",
        source: node.parent_id,
        target: node.id,
        kind: "hierarchy"
      }
    end
  end

  def link_edges
    LearningNodeLink
      .where(from_node_id: nodes.map(&:id))
      .pluck(:from_node_id, :to_node_id, :relation_kind)
      .map do |from_id, to_id, kind_int|
        kind = LearningNodeLink.relation_kinds.key(kind_int) || kind_int.to_s

        {
          id: "#{kind[0]}-#{from_id}-#{to_id}",
          source: from_id,
          target: to_id,
          kind: kind
        }
      end
  end

  def serialized_edges
    hierarchy_edges + link_edges
  end
end
