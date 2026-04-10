require "digest"

class SelfUnderstandingReportEligibilityService
  Result = Struct.new(
    :should_generate?,
    :reason,
    :latest_report,
    :source_snapshot,
    :source_digest,
    :source_updated_at,
    keyword_init: true
  )

  RECENT_MESSAGE_LIMIT = 24
  RECENT_SAVED_LIMIT = 12
  RECENT_AUTHORED_LIMIT = 10

  def initialize(user:)
    @user = user
  end

  def evaluate
    latest_report = @user.latest_self_understanding_report
    snapshot = build_source_snapshot
    digest = Digest::SHA256.hexdigest(JSON.generate(snapshot))

    Result.new(
      should_generate?: should_generate?(latest_report, snapshot, digest),
      reason: generation_reason(latest_report, snapshot, digest),
      latest_report: latest_report,
      source_snapshot: snapshot,
      source_digest: digest,
      source_updated_at: source_updated_at
    )
  end

  private

  def should_generate?(latest_report, snapshot, digest)
    return false unless @user.life?
    return false unless meaningful_signal?(snapshot)
    return true if latest_report.blank?

    latest_report.source_digest != digest
  end

  def generation_reason(latest_report, snapshot, digest)
    return "not_in_life_mode" unless @user.life?
    return "insufficient_signal" unless meaningful_signal?(snapshot)
    return "first_report" if latest_report.blank?
    return "unchanged" if latest_report.source_digest == digest

    "new_signal"
  end

  def meaningful_signal?(snapshot)
    snapshot.dig(:coach_profile, :facts).present? ||
      snapshot.dig(:user_profile, :goals).present? ||
      snapshot.dig(:user_profile, :skill_level).present? ||
      snapshot.dig(:user_profile, :handicap).present? ||
      snapshot.dig(:coaching_activity, :recent_messages).present? ||
      snapshot.dig(:saved_artifacts, :recent).present? ||
      snapshot.dig(:authored_artifacts, :recent).present?
  end

  def build_source_snapshot
    coach_profile = @user.coach_profile
    recent_messages = CoachMessage.joins(:coach_session)
                                  .where(coach_sessions: { user_id: @user.id })
                                  .includes(:coach_session)
                                  .order(created_at: :desc)
                                  .limit(RECENT_MESSAGE_LIMIT)

    recent_saved = @user.saved_tips.includes(tip: :category).order(created_at: :desc).limit(RECENT_SAVED_LIMIT)
    recent_authored = @user.tips.includes(:category).order(created_at: :desc).limit(RECENT_AUTHORED_LIMIT)

    {
      user_profile: {
        display_name: @user.display_name,
        skill_level: @user.skill_level,
        handicap: @user.handicap,
        goals: Array(@user.goals).reject(&:blank?),
        onboarding_completed: @user.onboarding_completed?,
        account_age_days: (Date.current - @user.created_at.to_date).to_i
      },
      coach_profile: {
        facts: coach_profile&.profile_data || {},
        learned_facts_count: coach_profile&.learned_facts_count || 0,
        last_synced_at: coach_profile&.last_synced_at&.iso8601,
        summary: coach_profile&.summary.to_s.presence
      },
      coaching_activity: {
        session_count: @user.coach_sessions.count,
        message_count: CoachMessage.joins(:coach_session).where(coach_sessions: { user_id: @user.id }).count,
        recent_messages: recent_messages.reverse.map do |message|
          {
            role: message.role,
            phase: message.coach_session.phase,
            content: squish_excerpt(message.content, limit: 280),
            created_at: message.created_at.iso8601
          }
        end
      },
      saved_artifacts: {
        count: @user.saved_tips.count,
        recent: recent_saved.map do |saved_tip|
          tip = saved_tip.tip
          {
            title: tip&.title,
            type: tip&.type || "Tip",
            category: tip&.category&.name,
            tags: tip&.tags || [],
            saved_at: saved_tip.created_at.iso8601
          }
        end
      },
      authored_artifacts: {
        count: @user.tips.count,
        recent: recent_authored.map do |tip|
          {
            title: tip.title,
            type: tip.type || "Tip",
            source: tip.source,
            category: tip.category&.name,
            created_at: tip.created_at.iso8601
          }
        end
      }
    }
  end

  def source_updated_at
    [
      @user.updated_at,
      @user.coach_profile&.updated_at,
      @user.coach_sessions.maximum(:updated_at),
      CoachMessage.joins(:coach_session).where(coach_sessions: { user_id: @user.id }).maximum(:updated_at),
      @user.saved_tips.maximum(:updated_at),
      @user.tips.maximum(:updated_at)
    ].compact.max
  end

  def squish_excerpt(text, limit:)
    text.to_s.squish.first(limit)
  end
end
