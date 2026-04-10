class LearningNodeCompilationService
  CHILD_TOPIC_LIMIT = 5

  def initialize(node:)
    @node = node
  end

  def call
    payload = NanoclawLearningBridgeService.compile_node(node: @node) || GeminiService.generate_structured_payload(
      prompt: build_prompt,
      temperature: 0.35,
      max_output_tokens: 3_000,
      label: "Gemini learning node compilation"
    )

    child_topics = normalize_child_topics(payload&.dig("child_topics"))
    related_titles = normalize_related_titles(payload&.dig("related_topics"))
    open_questions = Array(payload&.dig("open_questions")).filter_map { |entry| entry.to_s.strip.presence }.first(6)

    @node.update!(
      summary: payload&.dig("summary").to_s.strip.presence || fallback_summary,
      body_markdown: payload&.dig("body_markdown").to_s.strip.presence || fallback_body_markdown(child_topics:, open_questions:),
      status: :ready,
      metadata: @node.metadata.merge(
        "compiled_at" => Time.current.iso8601,
        "compiled_source_digest" => @node.compiled_source_digest,
        "open_questions" => open_questions
      )
    )

    sync_child_topics(child_topics)
    sync_related_topics(related_titles)

    @node
  end

  private

  def build_prompt
    <<~PROMPT
      You are compiling a markdown note for an Obsidian-like learning workspace.

      Topic:
      - Title: #{@node.title}
      - Parent: #{@node.parent&.title || "None"}
      - Existing summary: #{@node.summary.to_s.presence || "None yet"}

      Goals:
      - Produce a strong organizing note for this topic.
      - Favor clarity, teachability, and durable structure.
      - Use a gbrain-style pattern: current understanding first, evidence/history below.
      - When useful, use wiki-style references like [[Existing Topic Title]] for related notes or child topics.

      Return valid JSON only:
      {
        "summary": "2-3 sentence summary",
        "body_markdown": "Markdown note with sections such as Current Understanding, Structure, Sources, Evidence Timeline, and Open Questions",
        "child_topics": [
          {
            "title": "Subtopic title",
            "summary": "Why this deserves its own note"
          }
        ],
        "related_topics": ["Existing note title"],
        "open_questions": ["question"]
      }

      Constraints:
      - Keep child_topics to at most #{CHILD_TOPIC_LIMIT}.
      - Aim for a clean organizing structure, not exhaustive taxonomy.
      - If evidence is thin, say so.

      Existing user note titles you may link to:
      #{candidate_related_titles.join(', ')}

      Source summaries:
      #{formatted_sources}

      Existing child notes:
      #{formatted_children}

      Existing Q&A:
      #{formatted_questions}
    PROMPT
  end

  def candidate_related_titles
    @candidate_related_titles ||= @node.user.learning_nodes.where.not(id: @node.id).order(:title).limit(40).pluck(:title)
  end

  def formatted_sources
    sources = @node.learning_sources.order(quality_score: :desc, created_at: :asc)
    return "No sources yet." if sources.empty?

    sources.map do |source|
      <<~SOURCE
        - Source ##{source.id}: #{source.display_title}
          URL: #{source.url || "Uploaded file"}
          Quality score: #{source.quality_score}
          Summary:
          #{source.summary_markdown.to_s.presence || source.extracted_content.to_s.first(600) || "No summary yet."}
      SOURCE
    end.join("\n")
  end

  def formatted_children
    children = @node.ordered_children
    return "No child notes yet." if children.empty?

    children.map { |child| "- #{child.title}: #{child.summary.to_s.presence || 'No summary yet.'}" }.join("\n")
  end

  def formatted_questions
    questions = @node.learning_questions.answered.order(created_at: :desc).limit(6)
    return "No Q&A yet." if questions.empty?

    questions.reverse.map do |question|
      <<~QUESTION
        - Q: #{question.question_text}
          A: #{question.answer_markdown.to_s.first(500)}
      QUESTION
    end.join("\n")
  end

  def normalize_child_topics(raw_child_topics)
    Array(raw_child_topics).filter_map do |entry|
      next unless entry.is_a?(Hash)

      title = entry["title"].to_s.strip
      next if title.blank?

      {
        title: title,
        summary: entry["summary"].to_s.strip.presence
      }
    end.first(CHILD_TOPIC_LIMIT)
  end

  def normalize_related_titles(raw_titles)
    Array(raw_titles).filter_map { |entry| entry.to_s.strip.presence }.uniq.first(8)
  end

  def sync_child_topics(child_topics)
    child_topics.each_with_index do |topic, index|
      child = @node.children.where("LOWER(title) = ?", topic[:title].downcase).first_or_initialize
      was_new_record = child.new_record?
      child.user = @node.user
      child.parent = @node
      child.title = topic[:title]
      child.position = index
      child.summary = topic[:summary] if topic[:summary].present?
      child.node_kind ||= :topic
      child.status = :pending_research if was_new_record
      child.save!
    end
  end

  def sync_related_topics(related_titles)
    matches = @node.user.learning_nodes.where.not(id: @node.id).where("LOWER(title) IN (?)", related_titles.map(&:downcase))

    matches.find_each do |related_node|
      @node.outgoing_learning_node_links.find_or_create_by!(to_node: related_node, relation_kind: :related)
    end
  end

  def fallback_summary
    if @node.learning_sources.any?
      "#{@node.title} now has #{ActionController::Base.helpers.pluralize(@node.learning_sources.count, 'source')} collected into a working note."
    else
      "#{@node.title} is a learning topic waiting for deeper source collection and synthesis."
    end
  end

  def fallback_body_markdown(child_topics:, open_questions:)
    source_lines = @node.learning_sources.order(quality_score: :desc).map do |source|
      "- #{source.display_title}: #{source.summary_markdown.to_s.first(180).presence || 'Summary pending.'}"
    end

    child_lines = child_topics.map { |topic| "- [[#{topic[:title]}]]: #{topic[:summary].presence || 'Potential child note.'}" }
    question_lines = open_questions.map { |question| "- #{question}" }

    [
      "## Current Understanding",
      @node.summary.presence || fallback_summary,
      "",
      "## Structure",
      child_lines.presence || ["- No child topics suggested yet."],
      "",
      "## Sources",
      source_lines.presence || ["- No sources collected yet."],
      "",
      "## Evidence Timeline",
      @node.learning_sources.order(created_at: :desc).map do |source|
        "- #{source.created_at.to_date}: Added #{source.display_title}"
      end.presence || ["- No evidence events yet."],
      "",
      "## Open Questions",
      question_lines.presence || ["- What are the highest-quality next sources for this topic?"]
    ].flatten.join("\n")
  end
end
