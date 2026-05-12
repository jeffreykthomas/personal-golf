class LearningInsightSyncService
  ROOT_TITLE = "Personal Beliefs".freeze
  ROOT_SUMMARY = "Coach-saved thoughts, preferences, goals, and self-observations gathered from conversations.".freeze
  GENERAL_CATEGORY_TITLE = "General Beliefs".freeze

  def initialize(user:)
    @user = user
  end

  def call
    return if saved_insights.none?

    root = find_or_create_container!(
      parent: nil,
      title: ROOT_TITLE,
      summary: ROOT_SUMMARY,
      metadata: { "source" => "coach_insight_collection" }
    )

    saved_insights.each do |insight|
      category = find_or_create_container!(
        parent: root,
        title: category_title_for(insight),
        summary: "Coach-saved insights categorized as #{category_title_for(insight).downcase}.",
        metadata: {
          "source" => "coach_insight_category",
          "category_slug" => insight.category&.slug
        }.compact
      )

      find_or_create_insight_note!(parent: category, insight: insight)
    end
  end

  private

  attr_reader :user

  def saved_insights
    @saved_insights ||= user.saved_tip_items.insights.includes(:category).order(:created_at, :id).to_a
  end

  def find_or_create_container!(parent:, title:, summary:, metadata:)
    existing = user.learning_nodes.where(parent: parent).where("LOWER(title) = ?", title.downcase).first
    return existing if existing.present?

    user.learning_nodes.create!(
      parent: parent,
      title: title,
      summary: summary,
      body_markdown: "## Current Understanding\n\n#{summary}",
      node_kind: :cluster,
      status: :ready,
      metadata: metadata
    )
  end

  def find_or_create_insight_note!(parent:, insight:)
    existing = insight_nodes_by_tip_id[insight.id]
    return existing if existing.present?

    user.learning_nodes.create!(
      parent: parent,
      title: insight.title,
      summary: insight.content.to_s.truncate(180, separator: " "),
      body_markdown: insight_body_markdown(insight),
      node_kind: :generated_note,
      status: :ready,
      metadata: {
        "source" => "coach_insight",
        "tip_id" => insight.id,
        "category_slug" => insight.category&.slug,
        "tags" => insight.tags
      }.compact
    )
  end

  def insight_nodes_by_tip_id
    @insight_nodes_by_tip_id ||= user.learning_nodes.generated_note.each_with_object({}) do |node, index|
      next unless node.metadata["source"] == "coach_insight"

      tip_id = node.metadata["tip_id"].to_i
      index[tip_id] = node if tip_id.positive?
    end
  end

  def category_title_for(insight)
    insight.category&.name.presence ||
      insight.tags.first.to_s.tr("_", " ").titleize.presence ||
      GENERAL_CATEGORY_TITLE
  end

  def insight_body_markdown(insight)
    saved_at = insight.created_at&.strftime("%b %-d, %Y")

    <<~MARKDOWN
      ## Saved Thought

      #{insight.content}

      ## Source

      Saved by the coach#{saved_at.present? ? " on #{saved_at}" : ""}.
    MARKDOWN
  end
end
