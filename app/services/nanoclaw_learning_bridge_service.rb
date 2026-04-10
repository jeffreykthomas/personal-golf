require "json"
require "net/http"
require "securerandom"
require "uri"

class NanoclawLearningBridgeService
  DEFAULT_URL = "http://127.0.0.1:4317".freeze
  QUESTION_SOURCE_LIMIT = 12
  EXISTING_TITLE_LIMIT = 80
  RETRYABLE_ERRORS = [
    Timeout::Error,
    Errno::ECONNREFUSED,
    Errno::EHOSTUNREACH,
    Net::OpenTimeout,
    Net::ReadTimeout
  ].freeze

  class << self
    def discover_sources(node:)
      new.discover_sources(node:)
    end

    def compile_node(node:)
      new.compile_node(node:)
    end

    def answer_question(question:)
      new.answer_question(question:)
    end

    def rebalance_node(node:)
      new.rebalance_node(node:)
    end
  end

  def discover_sources(node:)
    perform_request(task_type: "discover_sources", node: node)
  end

  def compile_node(node:)
    perform_request(task_type: "compile_node", node: node)
  end

  def answer_question(question:)
    perform_request(task_type: "answer_question", node: question.learning_node, question: question)
  end

  def rebalance_node(node:)
    perform_request(task_type: "rebalance_node", node: node)
  end

  private

  def perform_request(task_type:, node:, question: nil)
    return nil unless bridge_enabled?

    response = with_retries(max_attempts: 1) do
      uri = URI.join(base_url, "/v1/learning/respond")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 5
      http.read_timeout = 240

      request = Net::HTTP::Post.new(uri.request_uri, request_headers)
      request.body = build_payload(task_type:, node:, question:).to_json
      http.request(request)
    end

    return nil unless response.is_a?(Net::HTTPSuccess)

    body = JSON.parse(response.body)
    payload = body["payload"]
    payload.is_a?(Hash) ? payload : nil
  rescue JSON::ParserError => e
    Rails.logger.warn("NanoClaw learning bridge returned invalid JSON task=#{task_type} node=#{node.id}: #{e.message}")
    nil
  rescue *RETRYABLE_ERRORS => e
    Rails.logger.warn("NanoClaw learning bridge unavailable task=#{task_type} node=#{node.id}: #{e.class} #{e.message}")
    nil
  rescue StandardError => e
    Rails.logger.warn("NanoClaw learning bridge failed task=#{task_type} node=#{node.id}: #{e.class} #{e.message}")
    nil
  end

  def bridge_enabled?
    return false if Rails.env.test? && ENV["ENABLE_NANOCLAW_LEARNING_BRIDGE"].blank?

    auth_token.present?
  end

  def base_url
    ENV["NANOCLAW_APP_URL"].presence || ENV["CLAW_SIBLING_URL"].presence || DEFAULT_URL
  end

  def auth_token
    ENV["CLAW_SIBLING_TOKEN"].to_s.presence || nanoclaw_env_value("CLAW_SIBLING_TOKEN")
  end

  def request_headers
    {
      "Content-Type" => "application/json",
      "Authorization" => "Bearer #{auth_token}"
    }
  end

  def build_payload(task_type:, node:, question:)
    {
      requestId: SecureRandom.uuid,
      transport: "app",
      userId: node.user_id,
      learningNodeId: node.id,
      taskType: task_type,
      node: node_payload(node),
      sources: source_payloads(node),
      children: child_payloads(node),
      relatedTitles: related_titles(node),
      existingTitles: existing_titles(node),
      question: question_payload(question)
    }.compact
  end

  def node_payload(node)
    {
      title: node.title,
      summary: node.summary.to_s,
      bodyMarkdown: node.body_markdown.to_s,
      parentTitle: node.parent&.title,
      breadcrumbs: node.breadcrumbs.map(&:title),
      metadata: node.metadata || {}
    }
  end

  def source_payloads(node)
    node.learning_sources.order(quality_score: :desc, created_at: :asc).map do |source|
      {
        id: source.id,
        title: source.display_title,
        url: source.url,
        sourceType: source.source_type,
        qualityScore: source.quality_score,
        publicationName: source.publication_name,
        authorName: source.author_name,
        publishedOn: source.published_on&.iso8601,
        summaryMarkdown: source.summary_markdown.to_s,
        extractedContent: source.extracted_content.to_s.first(4_000),
        citationLabel: source.citation_label
      }
    end
  end

  def child_payloads(node)
    node.ordered_children.map do |child|
      {
        id: child.id,
        title: child.title,
        summary: child.summary.to_s
      }
    end
  end

  def related_titles(node)
    node.explicit_and_backlinked_nodes.limit(QUESTION_SOURCE_LIMIT).pluck(:title)
  end

  def existing_titles(node)
    node.user.learning_nodes.where.not(id: node.id).order(:title).limit(EXISTING_TITLE_LIMIT).pluck(:title)
  end

  def question_payload(question)
    return nil unless question.present?

    {
      id: question.id,
      questionText: question.question_text
    }
  end

  def with_retries(max_attempts:)
    attempts = 0

    begin
      attempts += 1
      yield
    rescue *RETRYABLE_ERRORS
      raise if attempts >= max_attempts

      sleep(0.25 * attempts)
      retry
    end
  end

  def nanoclaw_env_value(key)
    env_path = Rails.root.join("nanoclaw-golf", ".env")
    return nil unless env_path.exist?

    File.foreach(env_path) do |line|
      next if line.start_with?("#")

      env_key, env_value = line.split("=", 2)
      next unless env_key == key

      return env_value.to_s.strip.delete_prefix('"').delete_prefix("'").delete_suffix('"').delete_suffix("'").presence
    end

    nil
  rescue StandardError => e
    Rails.logger.warn("NanoClaw learning bridge could not read local env #{env_path}: #{e.class} #{e.message}")
    nil
  end
end
