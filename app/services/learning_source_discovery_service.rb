require "digest"
require "cgi"
require "uri"

class LearningSourceDiscoveryService
  DISCOVERY_LIMIT = 5

  def initialize(node:)
    @node = node
  end

  def call(payload: nil)
    payload ||= NanoclawLearningBridgeService.discover_sources(node: @node)
    apply_sources(payload["sources"])
  end

  def apply_sources(raw_sources)
    sources = normalize_sources(raw_sources)
    created_sources = sources.filter_map do |source_data|
      create_or_update_source(source_data)
    end

    @node.update!(
      metadata: @node.metadata.merge(
        "last_discovered_at" => Time.current.iso8601,
        "last_discovery_count" => created_sources.count,
        "last_discovery_source" => "nanoclaw"
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
        summary_markdown: entry["summary_markdown"].to_s.strip.presence,
        metadata: {
          "why_relevant" => entry["why_relevant"].to_s.strip.presence,
          "key_points" => Array(entry["key_points"]).filter_map { |point| point.to_s.strip.presence }.first(5),
          "discovered_by" => "nanoclaw"
        }.compact
      }
    end.first(DISCOVERY_LIMIT)
  end

  def create_or_update_source(source_data)
    source = @node.learning_sources.find_or_initialize_by(url: source_data[:url])
    summary_markdown = source_data[:summary_markdown]
    source.assign_attributes(
      title: source_data[:title],
      publication_name: source_data[:publication_name],
      author_name: source_data[:author_name],
      published_on: source_data[:published_on],
      quality_score: source_data[:quality_score],
      metadata: (source.metadata || {}).merge(source_data[:metadata] || {})
    )

    if summary_markdown.present?
      source.extraction_status = :summarized
      source.summary_markdown = summary_markdown
      source.content_hash = Digest::SHA256.hexdigest(summary_markdown)
    elsif source.summary_markdown.blank?
      source.extraction_status = :discovered
      source.summary_markdown = nil
    end

    source.source_type = :agent_found if source.new_record?
    source.save!
    source
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn("Skipping discovered learning source for node=#{@node.id}: #{e.message}")
    nil
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
