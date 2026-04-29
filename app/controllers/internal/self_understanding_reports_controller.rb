module Internal
  class SelfUnderstandingReportsController < BaseController
    allow_unauthenticated_access only: %i[pending create]

    DEFAULT_LIMIT = 5
    MAX_LIMIT = 25

    def pending
      tasks = []

      User.life.find_each do |user|
        evaluation = SelfUnderstandingReportEligibilityService.new(user: user).evaluate
        next unless evaluation.should_generate?

        builder = report_builder_for(user:, evaluation:)
        tasks << builder.request_payload.merge(
          user_id: user.id,
          source_digest: evaluation.source_digest
        )

        break if tasks.size >= request_limit
      end

      render json: { tasks: tasks }
    end

    def create
      user = User.find(create_params.fetch(:user_id))
      evaluation = SelfUnderstandingReportEligibilityService.new(user: user).evaluate

      unless evaluation.should_generate?
        render json: skipped_payload(evaluation), status: :ok
        return
      end

      if create_params.fetch(:source_digest) != evaluation.source_digest
        render json: {
          status: "stale",
          reason: "source_digest_mismatch",
          expected_source_digest: evaluation.source_digest
        }, status: :conflict
        return
      end

      report = SelfUnderstandingReportPersistenceService.new(
        user: user,
        evaluation: evaluation,
        report_payload: report_params.to_h
      ).call

      status = report.previous_changes.key?("id") ? :created : :ok

      render json: {
        status: report.previous_changes.key?("id") ? "created" : "updated",
        report_id: report.id
      }, status: status
    rescue ActiveRecord::RecordNotFound
      render json: { error: "user_not_found" }, status: :not_found
    rescue ActionController::ParameterMissing => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end

    private

    def request_limit
      params.fetch(:limit, DEFAULT_LIMIT).to_i.clamp(1, MAX_LIMIT)
    end

    def report_builder_for(user:, evaluation:)
      SelfUnderstandingReportBuilderService.new(
        user: user,
        source_snapshot: evaluation.source_snapshot,
        source_digest: evaluation.source_digest,
        source_updated_at: evaluation.source_updated_at,
        latest_report: evaluation.latest_report
      )
    end

    def create_params
      params.permit(:user_id, :source_digest)
    end

    def report_params
      params.require(:report).permit(
        :title,
        :body_markdown,
        currents: [
          :name,
          :score,
          :summary,
          { signals: [] }
        ]
      )
    end

    def skipped_payload(evaluation)
      {
        status: "skipped",
        reason: evaluation.reason,
        report_id: evaluation.latest_report&.id
      }.compact
    end
  end
end
