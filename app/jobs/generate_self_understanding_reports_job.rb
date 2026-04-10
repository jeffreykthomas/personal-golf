class GenerateSelfUnderstandingReportsJob < ApplicationJob
  queue_as :ai_generation

  def perform(user_ids = nil)
    scope = User.life
    scope = scope.where(id: Array(user_ids)) if user_ids.present?

    scope.find_each do |user|
      generate_report_for(user)
    rescue StandardError => e
      Rails.logger.error("Self-understanding report generation failed for user=#{user.id}: #{e.class} #{e.message}")
    end
  end

  private

  def generate_report_for(user)
    evaluation = SelfUnderstandingReportEligibilityService.new(user: user).evaluate
    return unless evaluation.should_generate?

    attributes = SelfUnderstandingReportBuilderService.new(
      user: user,
      source_snapshot: evaluation.source_snapshot,
      source_digest: evaluation.source_digest,
      source_updated_at: evaluation.source_updated_at,
      latest_report: evaluation.latest_report
    ).call

    user.self_understanding_reports.create!(attributes)
  end
end
