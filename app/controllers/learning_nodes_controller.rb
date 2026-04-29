class LearningNodesController < ApplicationController
  before_action :require_life_mode!
  before_action :set_learning_node, only: [:update, :discover_sources, :compile, :rebalance, :promote_suggestion, :dismiss_suggestion]

  def create
    parent = current_user.learning_nodes.find_by(id: learning_node_params[:parent_id])
    @learning_node = current_user.learning_nodes.new(learning_node_params.except(:parent_id))
    @learning_node.parent = parent
    @learning_node.status = :pending_research if @learning_node.draft?

    if @learning_node.save
      LearningSourceDiscoveryJob.perform_later(@learning_node.id)
      redirect_to learning_path(node_id: @learning_node.id)
    else
      redirect_to learning_path(node_id: parent&.id), alert: @learning_node.errors.full_messages.to_sentence
    end
  end

  def update
    if @learning_node.update(learning_node_params.except(:parent_id))
      redirect_to learning_path(node_id: @learning_node.id)
    else
      redirect_to learning_path(node_id: @learning_node.id), alert: @learning_node.errors.full_messages.to_sentence
    end
  end

  def discover_sources
    LearningSourceDiscoveryJob.perform_later(@learning_node.id)
    redirect_to learning_path(node_id: @learning_node.id)
  end

  def compile
    LearningNodeCompilationJob.perform_later(@learning_node.id)
    redirect_to learning_path(node_id: @learning_node.id)
  end

  def rebalance
    LearningRebalancingService.new(node: @learning_node).call
    redirect_to learning_path(node_id: @learning_node.id)
  end

  def promote_suggestion
    title = suggestion_title_param
    redirect_with_alert(@learning_node.id, "Suggestion title is required.") and return if title.blank?

    suggestions = current_suggestions
    matched = suggestions.find { |entry| entry["title"].to_s.casecmp?(title) }
    redirect_with_alert(@learning_node.id, "That suggestion is no longer available.") and return unless matched

    existing = current_user.learning_nodes.where(parent: @learning_node).where("LOWER(title) = ?", title.downcase).first

    if existing
      remove_suggestion!(title)
      redirect_to learning_path(node_id: existing.id), notice: "Added existing child \"#{existing.title}\"."
      return
    end

    child = current_user.learning_nodes.new(
      parent: @learning_node,
      title: matched["title"],
      summary: matched["summary"].to_s.presence,
      node_kind: :topic,
      status: :draft
    )

    if child.save
      remove_suggestion!(title)
      redirect_to learning_path(node_id: child.id), notice: "Added \"#{child.title}\" as a child. Click Discover Sources to research it."
    else
      redirect_with_alert(@learning_node.id, child.errors.full_messages.to_sentence)
    end
  end

  def dismiss_suggestion
    title = suggestion_title_param
    redirect_with_alert(@learning_node.id, "Suggestion title is required.") and return if title.blank?

    remove_suggestion!(title, remember_dismissal: true)
    redirect_to learning_path(node_id: @learning_node.id), notice: "Dismissed suggestion \"#{title}\"."
  end

  private

  def suggestion_title_param
    params[:title].to_s.strip
  end

  def current_suggestions
    Array(@learning_node.metadata["suggested_child_topics"]).select { |entry| entry.is_a?(Hash) }
  end

  def remove_suggestion!(title, remember_dismissal: false)
    suggestions = current_suggestions.reject { |entry| entry["title"].to_s.casecmp?(title) }
    metadata = @learning_node.metadata.merge("suggested_child_topics" => suggestions)

    if remember_dismissal
      dismissed = Array(metadata["dismissed_suggestion_titles"]).map(&:to_s)
      dismissed << title unless dismissed.any? { |existing| existing.casecmp?(title) }
      metadata["dismissed_suggestion_titles"] = dismissed
    end

    @learning_node.update!(metadata: metadata)
  end

  def redirect_with_alert(node_id, message)
    redirect_to learning_path(node_id: node_id), alert: message
  end

  def set_learning_node
    @learning_node = current_user.learning_nodes.find(params[:id])
  end

  def learning_node_params
    params.require(:learning_node).permit(:title, :summary, :body_markdown, :node_kind, :parent_id)
  end
end
