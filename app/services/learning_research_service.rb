class LearningResearchService
  def initialize(node:)
    @node = node
  end

  def call
    payload = NanoclawLearningBridgeService.research_node(node: @node)

    ActiveRecord::Base.transaction do
      LearningSourceDiscoveryService.new(node: @node).apply_sources(payload["sources"])
      LearningNodeCompilationService.new(node: @node).apply_payload(payload)

      @node.update!(
        metadata: @node.metadata.merge(
          "last_researched_at" => Time.current.iso8601,
          "last_research_source" => "nanoclaw"
        )
      )
    end

    @node
  rescue StandardError => e
    Rails.logger.error("Learning research failed node=#{@node.id}: #{e.class} #{e.message}")
    @node.update(
      metadata: (@node.metadata || {}).merge(
        "last_research_error" => e.message,
        "last_research_failed_at" => Time.current.iso8601
      )
    )
    raise
  end
end
