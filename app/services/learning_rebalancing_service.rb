class LearningRebalancingService
  BUCKET_LIMIT = 5

  def initialize(node:)
    @node = node
  end

  def call
    movable_children = @node.children.where.not(node_kind: :cluster).order(:position, :title).to_a
    return false if movable_children.count <= LearningNode::MAX_CHILDREN_PER_LEVEL

    payload = NanoclawLearningBridgeService.rebalance_node(node: @node) || GeminiService.generate_structured_payload(
      prompt: build_prompt(movable_children),
      temperature: 0.25,
      max_output_tokens: 1_800,
      label: "Gemini learning rebalancing"
    )

    buckets = normalize_buckets(payload&.dig("buckets"))
    return false if buckets.empty?

    @node.update!(status: :rebalancing)

    buckets.each_with_index do |bucket, index|
      bucket_node = @node.children.cluster.find_by("LOWER(title) = ?", bucket[:title].downcase) || @node.children.build
      bucket_node.user = @node.user
      bucket_node.parent = @node
      bucket_node.title = bucket[:title]
      bucket_node.summary = bucket[:summary]
      bucket_node.node_kind = :cluster
      bucket_node.status = :ready
      bucket_node.position = index
      bucket_node.save!

      bucket[:child_titles].each_with_index do |child_title, child_index|
        child = movable_children.find { |entry| entry.title.casecmp?(child_title) }
        next unless child

        child.update!(parent: bucket_node, position: child_index)
      end
    end

    @node.update!(
      status: :ready,
      metadata: @node.metadata.merge("last_rebalanced_at" => Time.current.iso8601)
    )

    true
  end

  private

  def build_prompt(children)
    <<~PROMPT
      You are reorganizing an Obsidian-like topic tree.

      Parent topic: #{@node.title}

      Current direct children:
      #{children.map { |child| "- #{child.title}: #{child.summary.to_s.presence || 'No summary yet.'}" }.join("\n")}

      Task:
      Group these child notes into 2 to #{BUCKET_LIMIT} cleaner buckets.
      Aim for clear mental models, not arbitrary taxonomies.

      Return valid JSON only:
      {
        "buckets": [
          {
            "title": "Bucket title",
            "summary": "What belongs here",
            "child_titles": ["Existing Child Title", "Another Child Title"]
          }
        ]
      }
    PROMPT
  end

  def normalize_buckets(raw_buckets)
    Array(raw_buckets).filter_map do |entry|
      next unless entry.is_a?(Hash)

      title = entry["title"].to_s.strip
      child_titles = Array(entry["child_titles"]).filter_map { |child| child.to_s.strip.presence }
      next if title.blank? || child_titles.empty?

      {
        title: title,
        summary: entry["summary"].to_s.strip.presence,
        child_titles: child_titles
      }
    end.first(BUCKET_LIMIT)
  end
end
