class LearningQuestionAnsweringService
  def initialize(question:)
    @question = question
    @node = question.learning_node
  end

  def call
    payload = NanoclawLearningBridgeService.answer_question(question: @question) || GeminiService.generate_structured_payload(
      prompt: build_prompt,
      temperature: 0.35,
      max_output_tokens: 1_800,
      label: "Gemini learning question answering"
    )

    citations = normalize_citations(payload&.dig("citations"))

    @question.update!(
      answer_markdown: payload&.dig("answer_markdown").to_s.strip.presence || fallback_answer(citations),
      citations_data: citations,
      status: :answered,
      answered_at: Time.current,
      metadata: (@question.metadata || {}).merge("answered_by" => "agent")
    )

    @question
  rescue StandardError => e
    Rails.logger.error("Learning Q&A failed question=#{@question.id}: #{e.class} #{e.message}")
    @question.update!(
      status: :failed,
      answer_markdown: "I could not answer this question from the current learning context yet.",
      metadata: (@question.metadata || {}).merge("last_error" => e.message)
    )
    @question
  end

  private

  def build_prompt
    <<~PROMPT
      You are answering a question inside a topic-specific learning workspace.

      Topic note:
      Title: #{@node.title}
      Summary: #{@node.summary.to_s.presence || "None"}
      Body markdown:
      #{@node.body_markdown.to_s.presence || "No compiled note yet."}

      Available sources:
      #{formatted_sources}

      User question:
      #{@question.question_text}

      Requirements:
      - Answer only from the topic note and available sources.
      - If the evidence is weak or incomplete, say so clearly.
      - Cite the most relevant sources.

      Return valid JSON only:
      {
        "answer_markdown": "Markdown answer",
        "citations": [
          {
            "source_id": 123,
            "title": "Source title",
            "reason": "How this source supports the answer"
          }
        ]
      }
    PROMPT
  end

  def formatted_sources
    sources = @node.learning_sources.summarized.order(quality_score: :desc, created_at: :asc)
    return "No summarized sources available." if sources.empty?

    sources.map do |source|
      <<~SOURCE
        - Source ##{source.id}: #{source.display_title}
          URL: #{source.url || "Uploaded file"}
          Summary:
          #{source.summary_markdown.to_s}
      SOURCE
    end.join("\n")
  end

  def normalize_citations(raw_citations)
    Array(raw_citations).filter_map do |entry|
      next unless entry.is_a?(Hash)

      source_id = entry["source_id"].to_i
      source = @node.learning_sources.find_by(id: source_id)
      next unless source

      {
        "source_id" => source.id,
        "title" => entry["title"].to_s.strip.presence || source.display_title,
        "reason" => entry["reason"].to_s.strip.presence || "Relevant supporting source."
      }
    end
  end

  def fallback_answer(citations)
    lines = [
      "## Answer",
      "There is not enough compiled evidence in this topic yet to answer that confidently."
    ]

    if citations.any?
      lines += ["", "## Sources to inspect next"] + citations.map { |citation| "- #{citation['title']}: #{citation['reason']}" }
    end

    lines.join("\n")
  end
end
