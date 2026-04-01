# app/helpers/tips_helper.rb
module TipsHelper
  def should_show_swipe_hint?(user)
    # Show hint for first 3 tips or if user hasn't swiped recently
    user.tips_viewed_count < 3 ||
    user.saved_tips.none? ||
    user.created_at > 1.hour.ago
  end

  def next_tip_for_user(user, exclude_ids = [])
    # Smart tip selection based on user preferences and engagement
    tips = Tip.published
              .where.not(id: exclude_ids)
              .where.not(id: user.saved_tip_items.pluck(:id))
              .includes(:user, :category)
              .order(save_count: :desc, created_at: :desc)
              .limit(10)
    
    # Select the most relevant tip based on calculated score
    tips.max_by(&:relevance_score)
  end
  
  def tip_phase_icon(phase)
    case phase
    when 'pre_round'
      '🎯'
    when 'during_round'
      '⛳'
    when 'post_round'
      '📊'
    else
      '🏌️'
    end
  end

  def tip_phase_key(tip)
    raw_phase = tip.phase_before_type_cast
    return raw_phase if raw_phase.is_a?(String) && Tip.phases.key?(raw_phase)
    return nil if raw_phase.blank?

    Tip.phases.key(raw_phase.to_i)
  rescue StandardError
    nil
  end

  def tip_phase_label(tip)
    return "Insight" if tip.type == "Insight"

    tip_phase_key(tip)&.humanize || "General"
  end
  
  def tip_phase_icon_for(tip)
    return "🧠" if tip.type == "Insight"

    tip_phase_icon(tip_phase_key(tip))
  end

  def tip_category_label(tip)
    tip.category&.name || tip.type.to_s.demodulize.presence || "Tip"
  end

  def tip_source_label(tip)
    tip.source.to_s.humanize.presence || "Coach"
  end
  
  def skill_level_badge(level)
    colors = {
      'beginner' => 'bg-blue-500/10 text-blue-400 border-blue-500/20',
      'intermediate' => 'bg-amber-500/10 text-amber-400 border-amber-500/20',
      'advanced' => 'bg-red-500/10 text-red-400 border-red-500/20'
    }
    
    colors[level] || colors['beginner']
  end
end