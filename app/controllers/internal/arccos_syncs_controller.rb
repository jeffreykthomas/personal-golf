module Internal
  class ArccosSyncsController < BaseController
    allow_unauthenticated_access only: %i[pending create start fail]

    DEFAULT_LIMIT = 5
    MAX_LIMIT = 25
    DEFAULT_CUTOFF_MONTHS = 6
    # Cap how many external_ids we echo back per task to keep the bridge
    # prompt reasonable; weekly deltas only need recent history.
    KNOWN_EXTERNAL_IDS_LIMIT = 400

    def pending
      tasks = []

      eligible_users.find_each do |user|
        profile = ArccosProfile.for(user)
        next if profile.fresh?(within: stale_after) && !force_sync?

        tasks << build_task(user, profile)

        break if tasks.size >= request_limit
      end

      render json: { tasks: tasks }
    end

    def eligible_users
      scope = User.all
      if params[:user_id].present?
        scope.where(id: params[:user_id])
      else
        scope
      end
    end

    def force_sync?
      ActiveModel::Type::Boolean.new.cast(params[:force])
    end

    def start
      user = User.find(params[:user_id])
      profile = ArccosProfile.for(user)
      profile.update!(last_sync_status: "running", last_sync_error: nil)
      render json: { status: "running", profile: profile_summary(profile) }
    rescue ActiveRecord::RecordNotFound
      render json: { error: "user_not_found" }, status: :not_found
    end

    def create
      user = User.find(params.fetch(:user_id))
      payload_root = params[:payload].presence || params[:sync]
      raise ActionController::ParameterMissing, :payload if payload_root.blank?

      payload = payload_root.respond_to?(:permit!) ? payload_root.permit!.to_h : payload_root.to_h
      result = ArccosSyncPersistenceService.new(user: user, payload: payload).call

      render json: {
        status: "ok",
        profile: profile_summary(result.profile),
        rounds_inserted: result.rounds_inserted,
        rounds_updated: result.rounds_updated,
        source_digest: result.source_digest
      }
    rescue ActiveRecord::RecordNotFound
      render json: { error: "user_not_found" }, status: :not_found
    rescue ActionController::ParameterMissing => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end

    def fail
      user = User.find(params.fetch(:user_id))
      message = params[:message].to_s.presence || "unknown_failure"
      profile = ArccosProfile.for(user)
      profile.save! if profile.new_record?
      profile.record_failure!(message)

      render json: { status: "failed", profile: profile_summary(profile) }
    rescue ActiveRecord::RecordNotFound
      render json: { error: "user_not_found" }, status: :not_found
    end

    private

    def request_limit
      params.fetch(:limit, DEFAULT_LIMIT).to_i.clamp(1, MAX_LIMIT)
    end

    def stale_after
      seconds = params[:stale_after_seconds].to_i
      return 7.days if seconds <= 0

      seconds.seconds
    end

    def build_task(user, profile)
      cutoff_date = (Time.zone.today - cutoff_months.months).iso8601
      known_ids = user.arccos_rounds
        .where.not(external_id: [nil, ""])
        .where("played_on >= ?", cutoff_date)
        .order(played_on: :desc)
        .limit(KNOWN_EXTERNAL_IDS_LIMIT)
        .pluck(:external_id)

      {
        user_id: user.id,
        cutoff_date: cutoff_date,
        known_external_ids: known_ids,
        max_rounds: max_rounds,
        force: force_sync?,
        last_synced_at: profile.last_synced_at&.iso8601,
        last_sync_status: profile.last_sync_status,
        last_sync_source_digest: profile.last_sync_source_digest
      }
    end

    def cutoff_months
      months = params[:cutoff_months].to_i
      months.positive? ? months : DEFAULT_CUTOFF_MONTHS
    end

    def max_rounds
      value = params[:max_rounds].to_i
      value.positive? ? value : 150
    end

    def profile_summary(profile)
      {
        id: profile.id,
        user_id: profile.user_id,
        last_synced_at: profile.last_synced_at&.iso8601,
        last_sync_status: profile.last_sync_status,
        last_sync_error: profile.last_sync_error,
        handicap_index: profile.handicap_index,
        scoring_average: profile.scoring_average,
        rounds_tracked: profile.rounds_tracked
      }
    end
  end
end
