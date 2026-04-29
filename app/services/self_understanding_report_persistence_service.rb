class SelfUnderstandingReportPersistenceService
  def initialize(user:, evaluation:, report_payload:)
    @user = user
    @evaluation = evaluation
    @report_payload = report_payload
  end

  def call
    report = @user.self_understanding_reports.find_or_initialize_by(source_digest: @evaluation.source_digest)
    report.assign_attributes(builder.build_attributes(report_payload: @report_payload))
    report.save! if report.new_record? || report.changed?
    report
  end

  private

  def builder
    @builder ||= SelfUnderstandingReportBuilderService.new(
      user: @user,
      source_snapshot: @evaluation.source_snapshot,
      source_digest: @evaluation.source_digest,
      source_updated_at: @evaluation.source_updated_at,
      latest_report: @evaluation.latest_report
    )
  end
end
