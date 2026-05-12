class SelfUnderstandingReportBuilderService
  FRAMEWORK_NAME = SelfUnderstandingReport::FRAMEWORK_NAME
  CURRENT_ORDER = SelfUnderstandingReport::CURRENT_ORDER

  def initialize(user:, source_snapshot:, source_digest:, source_updated_at:, latest_report: nil)
    @user = user
    @source_snapshot = source_snapshot
    @source_digest = source_digest
    @source_updated_at = source_updated_at
    @latest_report = latest_report
  end

  def request_payload
    {
      framework_name: FRAMEWORK_NAME,
      current_order: CURRENT_ORDER,
      current_definitions: NineCurrents::DEFINITIONS.map(&:to_h),
      prompt: prompt,
      source_updated_at: @source_updated_at&.iso8601
    }.compact
  end

  def prompt
    <<~PROMPT
      You are generating a reflective personal synthesis for a product called Personal Life.

      Goal:
      Produce a concise Self-Understanding Report based only on the evidence provided.
      The framework name is "#{FRAMEWORK_NAME}".
      It is inspired by enneagram-style pattern recognition, but it is not the enneagram and must not map the user to a fixed type.
      Treat these as dynamic currents that move through a person's behavior over time. A person can express many currents at once.

      The nine currents are:
      #{CURRENT_ORDER.join(', ')}

      Current definitions:
      #{NineCurrents.prompt_context}

      Output requirements:
      - Return valid JSON only.
      - Do not wrap the JSON in markdown fences.
      - Be evidence-based, specific, and honest about uncertainty.
      - Do not make medical, psychiatric, or diagnostic claims.
      - Use a warm, observant tone, not therapy-speak or corporate language.
      - If the evidence is thin, avoid over-claiming.
      - Do not repeat formulaic "no new evidence" or "not enough evidence" caveats across currents.
      - Use each current's confidence field to carry evidence strength; prose should state what is known, hinted, or genuinely absent only when it helps.

      JSON shape:
      {
        "title": "Short report title",
        "body_markdown": "A concise markdown report with sections for overall pattern, strongest currents, quieter or hinted currents, tensions, opportunities, and what evidence would sharpen the picture.",
        "currents": [
          {
            "name": "Drive",
            "score": 1,
            "confidence": "low",
            "summary": "1-2 sentence explanation",
            "signals": ["short evidence point", "short evidence point"]
          }
        ]
      }

      Rules for currents:
      - Return exactly 9 current objects, one for each current listed above.
      - Keep scores as integers from 1 to 10.
      - Confidence must be one of "low", "medium", or "high"; it should reflect evidence quantity, quality, recency, and continuity with the previous report.
      - Each summary should be grounded in the evidence and should state what is known or hinted at directly.
      - Each signals array should have 1 to 3 concise evidence points.
      - Do not use repeated "no new evidence" phrasing in summaries; lower confidence is the place to show thin or stale evidence.
      - Use the current definitions as lenses, not as fixed personality labels.
      - Do not mention Enneagram numbers in the report unless the user explicitly asks.

      Previous report for continuity (if any):
      #{previous_report_context}

      Source evidence:
      #{JSON.pretty_generate(@source_snapshot)}
    PROMPT
  end

  def build_attributes(report_payload:, generated_at: Time.current)
    payload = report_payload.to_h.deep_stringify_keys
    {
      framework_name: FRAMEWORK_NAME,
      title: payload["title"].presence || "Self-Understanding Report",
      body_markdown: payload["body_markdown"].presence || fallback_body_markdown(payload),
      currents_data: { "currents" => normalize_currents(payload["currents"]) },
      source_snapshot: @source_snapshot,
      source_digest: @source_digest,
      source_updated_at: @source_updated_at,
      generated_at: generated_at
    }
  end

  private

  def previous_report_context
    return "None yet." unless @latest_report.present?

    @latest_report.body_markdown.to_s.first(3_000)
  end

  def normalize_currents(raw_currents)
    indexed = Array(raw_currents).index_by { |current| current["name"] }

    CURRENT_ORDER.map do |name|
      current = indexed[name] || {}
      {
        "name" => name,
        "score" => normalize_score(current["score"]),
        "confidence" => normalize_confidence(current["confidence"], current["signals"]),
        "summary" => current["summary"].to_s.presence || "This current is only lightly sketched by the available evidence.",
        "signals" => Array(current["signals"]).filter_map(&:presence).first(3)
      }
    end
  end

  def normalize_score(value)
    number = value.to_i
    return 5 if number <= 0
    return 10 if number > 10

    number
  end

  def normalize_confidence(value, raw_signals)
    normalized = value.to_s.downcase
    return normalized if %w[low medium high].include?(normalized)

    signal_count = Array(raw_signals).filter_map(&:presence).size
    return "high" if signal_count >= 3
    return "medium" if signal_count >= 2

    "low"
  end

  def fallback_body_markdown(payload)
    [
      "## Overall pattern",
      payload["title"].presence || "A first-pass self-understanding synthesis is available, but the full narrative came back incomplete.",
      "",
      "## Nine Currents",
      normalize_currents(payload["currents"]).map do |current|
        "- #{current['name']}: #{current['score']}/10, #{current['confidence']} confidence"
      end
    ].flatten.join("\n")
  end
end
