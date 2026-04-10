require "cgi"
require "uri"

class LearningSourceDiscoveryService
  DISCOVERY_LIMIT = 5

  def initialize(node:)
    @node = node
  end

  def call
    payload = NanoclawLearningBridgeService.discover_sources(node: @node) || GeminiService.generate_structured_payload(
      prompt: build_prompt,
      temperature: 0.3,
      max_output_tokens: 2_000,
      label: "Gemini learning source discovery"
    )

    sources = normalize_sources(payload&.dig("sources"))
    sources = fallback_sources if sources.empty?

    created_sources = sources.filter_map do |source_data|
      create_or_update_source(source_data)
    end

    @node.update!(
      metadata: @node.metadata.merge(
        "last_discovered_at" => Time.current.iso8601,
        "last_discovery_count" => created_sources.count
      )
    )

    created_sources
  end

  private

  def build_prompt
    <<~PROMPT
      You are helping build a learning workspace for a user.

      Topic:
      - Title: #{@node.title}
      - Summary: #{@node.summary.to_s.presence || "No summary yet"}
      - Parent topic: #{@node.parent&.title || "None"}

      Task:
      Suggest #{DISCOVERY_LIMIT} high-quality sources for learning this topic.
      Favor academic, primary, institutional, reference, and strong secondary sources where appropriate.
      If the topic benefits from arXiv or other research repositories, include them.
      Prioritize quality over popularity.

      Return valid JSON only:
      {
        "sources": [
          {
            "title": "Source title",
            "url": "https://example.com",
            "publication_name": "Publisher or site",
            "author_name": "Author if known",
            "published_on": "YYYY-MM-DD or null",
            "quality_score": 1-100,
            "why_relevant": "Short explanation"
          }
        ]
      }
    PROMPT
  end

  def normalize_sources(raw_sources)
    Array(raw_sources).filter_map do |entry|
      next unless entry.is_a?(Hash)

      url = normalize_url(entry["url"])
      next if url.blank?

      {
        title: entry["title"].to_s.strip.presence || url,
        url: url,
        publication_name: entry["publication_name"].to_s.strip.presence,
        author_name: entry["author_name"].to_s.strip.presence,
        published_on: normalize_date(entry["published_on"]),
        quality_score: normalize_quality_score(entry["quality_score"]),
        metadata: {
          "why_relevant" => entry["why_relevant"].to_s.strip.presence,
          "discovered_by" => "agent"
        }.compact
      }
    end.first(DISCOVERY_LIMIT)
  end

  def create_or_update_source(source_data)
    source = @node.learning_sources.find_or_initialize_by(url: source_data[:url])
    source.assign_attributes(
      title: source_data[:title],
      publication_name: source_data[:publication_name],
      author_name: source_data[:author_name],
      published_on: source_data[:published_on],
      quality_score: source_data[:quality_score],
      extraction_status: :discovered,
      metadata: (source.metadata || {}).merge(source_data[:metadata] || {})
    )
    source.source_type = :agent_found if source.new_record?
    source.save!
    source
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn("Skipping discovered learning source for node=#{@node.id}: #{e.message}")
    nil
  end

  def fallback_sources
    topic = CGI.escape(@node.title)

    [
      {
        title: "#{@node.title} on Wikipedia",
        url: "https://en.wikipedia.org/wiki/#{@node.title.to_s.parameterize(separator: '_')}",
        publication_name: "Wikipedia",
        author_name: nil,
        published_on: nil,
        quality_score: 55,
        metadata: { "why_relevant" => "Broad reference overview.", "discovered_by" => "fallback" }
      },
      {
        title: "Scholar results for #{@node.title}",
        url: "https://scholar.google.com/scholar?q=#{topic}",
        publication_name: "Google Scholar",
        author_name: nil,
        published_on: nil,
        quality_score: 65,
        metadata: { "why_relevant" => "Academic source discovery starting point.", "discovered_by" => "fallback" }
      },
      {
        title: "arXiv search for #{@node.title}",
        url: "https://arxiv.org/search/?query=#{topic}&searchtype=all",
        publication_name: "arXiv",
        author_name: nil,
        published_on: nil,
        quality_score: 70,
        metadata: { "why_relevant" => "Research repository search results.", "discovered_by" => "fallback" }
      }
    ]
  end

  def normalize_url(url)
    uri = URI.parse(url.to_s.strip)
    return nil unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)

    uri.to_s
  rescue URI::InvalidURIError
    nil
  end

  def normalize_date(value)
    return if value.blank?

    Date.parse(value.to_s)
  rescue ArgumentError
    nil
  end

  def normalize_quality_score(value)
    number = value.to_i
    return 50 if number <= 0
    return 100 if number > 100

    number
  end
end
