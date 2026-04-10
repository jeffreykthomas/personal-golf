module LearningHelper
  def learning_status_badge_classes(status)
    {
      "draft" => "bg-dark-bg text-dark-text-muted border-dark-border",
      "pending_research" => "bg-amber-500/10 text-amber-300 border-amber-500/20",
      "ready" => "bg-emerald-500/10 text-emerald-300 border-emerald-500/20",
      "rebalancing" => "bg-purple-500/10 text-purple-300 border-purple-500/20",
      "archived" => "bg-dark-bg text-dark-text-muted border-dark-border"
    }.fetch(status.to_s, "bg-dark-bg text-dark-text-muted border-dark-border")
  end

  def learning_source_status_badge_classes(status)
    {
      "discovered" => "bg-blue-500/10 text-blue-300 border-blue-500/20",
      "fetching" => "bg-blue-500/10 text-blue-300 border-blue-500/20",
      "summarized" => "bg-emerald-500/10 text-emerald-300 border-emerald-500/20",
      "needs_review" => "bg-amber-500/10 text-amber-300 border-amber-500/20",
      "failed" => "bg-red-500/10 text-red-300 border-red-500/20"
    }.fetch(status.to_s, "bg-dark-bg text-dark-text-muted border-dark-border")
  end
end
