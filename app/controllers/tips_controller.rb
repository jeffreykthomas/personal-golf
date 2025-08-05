class TipsController < ApplicationController
  before_action :ensure_onboarding_completed
  before_action :set_tip, only: [:save, :unsave]

  def index
    @tips = current_user.saved_tip_items.includes(:category, :user)
    @next_tip = find_next_tip
  end

  def next
    @tip = find_next_tip
    
    # Mark the current tip as viewed (for skip functionality)
    if params[:skip_tip_id].present?
      mark_tip_as_viewed(params[:skip_tip_id])
    end
    
    respond_to do |format|
      format.html { redirect_to tips_path }
      format.turbo_stream { render_next_tip_turbo_stream(@tip) }
    end
  end

  def save
    @saved_tip = current_user.save_tip(@tip)
    
    # Mark this tip as viewed as well
    mark_tip_as_viewed(@tip.id)
    
    respond_to do |format|
      format.json { render json: { status: 'success', saved: true } }
      format.turbo_stream do
        @next_tip = find_next_tip
        render_next_tip_turbo_stream(@next_tip)
      end
    end
  end

  def unsave
    saved_tip = current_user.saved_tips.find_by(tip: @tip)
    saved_tip&.destroy
    
    respond_to do |format|
      format.json { render json: { status: 'success', saved: false } }
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove("saved-tip-#{@tip.id}")
      end
    end
  end

  def saved
    @saved_tips = current_user.saved_tip_items.includes(:category, :user).order(created_at: :desc)
  end
  
  def request_ai_tips
    # Allow users to manually request tip generation
    tips_to_generate = params[:count]&.to_i || 5
    tips_to_generate = [tips_to_generate, 10].min # Max 10 at once
    
    # Check rate limiting
    cache_key = "manual_tip_generation_#{current_user.id}"
    if Rails.cache.exist?(cache_key)
      render json: { 
        error: 'Please wait before requesting more tips',
        retry_after: Rails.cache.read(cache_key)
      }, status: 429
      return
    end
    
    # Queue the generation
    GenerateTipsJob.perform_later(current_user.id, tips_to_generate)
    
    # Rate limit: 1 manual request per 10 minutes
    Rails.cache.write(cache_key, Time.current + 10.minutes, expires_in: 10.minutes)
    
    render json: { 
      status: 'queued',
      message: "Generating #{tips_to_generate} personalized tips for you!",
      estimated_time: "#{tips_to_generate * 2} seconds"
    }
  end

  private

  def ensure_onboarding_completed
    unless current_user.onboarding_completed?
      redirect_to onboarding_welcome_path, notice: "Please complete onboarding first."
    end
  end

  def set_tip
    @tip = Tip.find(params[:id])
  end

  def mark_tip_as_viewed(tip_id)
    session[:viewed_tip_ids] ||= []
    session[:viewed_tip_ids] << tip_id.to_i unless session[:viewed_tip_ids].include?(tip_id.to_i)
    
    # Limit session storage to last 100 viewed tips to prevent session bloat
    session[:viewed_tip_ids] = session[:viewed_tip_ids].last(100)
  end

  def find_next_tip
    # Get IDs of tips the user has already seen or saved
    saved_tip_ids = current_user.saved_tip_items.pluck(:id)
    viewed_tip_ids = session[:viewed_tip_ids] || []
    excluded_tip_ids = (saved_tip_ids + viewed_tip_ids).uniq
    
    # Find next tip based on user preferences
    tips = Tip.published
              .where.not(id: excluded_tip_ids)
              .where("skill_level <= ?", User.skill_levels[current_user.skill_level] || 2)
              .includes(:category, :user)
              .order(save_count: :desc, created_at: :desc)
              .limit(10)
    
    # Check if we need to generate more tips (but don't block the request)
    check_and_queue_tip_generation(tips.count, excluded_tip_ids.count)
    
    # Sort by relevance score in Ruby
    tips.max_by(&:relevance_score)
  end

  def render_next_tip_turbo_stream(tip)
    if tip
      render turbo_stream: turbo_stream.replace(
        "tip-display",
        partial: "tips/swipeable_tip_card",
        locals: { tip: tip }
      )
    else
      render turbo_stream: turbo_stream.replace(
        "tip-display",
        html: render_to_string(partial: "tips/no_more_tips")
      )
    end
  end
  
  def check_and_queue_tip_generation(available_tips_count, total_viewed_count)
    # Don't generate if user hasn't engaged much yet
    return if total_viewed_count < 5
    
    # Queue generation if running low on tips
    if available_tips_count < 10
      # Check if we recently queued generation (avoid spam)
      cache_key = "tip_generation_queued_#{current_user.id}"
      return if Rails.cache.exist?(cache_key)
      
      # Queue tip generation job
      tips_to_generate = [15 - available_tips_count, 5].max # Generate 5-15 tips
      GenerateTipsJob.perform_later(current_user.id, tips_to_generate)
      
      # Cache to prevent duplicate jobs for 30 minutes
      Rails.cache.write(cache_key, true, expires_in: 30.minutes)
      
      Rails.logger.info "Queued generation of #{tips_to_generate} tips for user #{current_user.id} (#{available_tips_count} available)"
    end
  end
end