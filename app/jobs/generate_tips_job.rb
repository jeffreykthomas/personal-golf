# app/jobs/generate_tips_job.rb
class GenerateTipsJob < ApplicationJob
  queue_as :ai_generation
  
  def perform(user_id, requested_count = 5)
    user = User.find(user_id)
    
    Rails.logger.info "Generating #{requested_count} tips for user #{user.id}"
    
    successful_generations = 0
    categories = determine_categories_for_user(user)
    
    # Ensure we have categories to work with
    if categories.empty?
      Rails.logger.warn "No categories found for user #{user.id}, using default categories"
      categories = Category.limit(3).to_a
    end
    
    requested_count.times do |i|
      category = categories[i % categories.length]
      
      tip_data = GeminiService.generate_tip(
        user_profile: user.profile_for_ai,
        category: category.name,
        context: build_context_for_user(user, category)
      )
      
      if tip_data
        tip = create_ai_tip(user, category, tip_data)
        if tip&.persisted?
          successful_generations += 1
          Rails.logger.debug "Created AI tip: #{tip.title}"
        end
      else
        Rails.logger.warn "Failed to generate tip for category #{category.name}"
      end
      
      # Small delay to avoid hitting API rate limits
      sleep(0.5) unless Rails.env.test?
    end
    
    Rails.logger.info "Successfully generated #{successful_generations}/#{requested_count} tips for user #{user.id}"
    
    # Notify user if they're online and we generated tips
    broadcast_new_tips_notification(user, successful_generations) if successful_generations > 0
    
    successful_generations
  end
  
  private
  
  def determine_categories_for_user(user)
    # Get user's saved tip categories (their preferences)
    saved_categories = user.saved_tip_items
                          .joins(:category)
                          .group('categories.id, categories.name')
                          .order('count(categories.id) desc')
                          .limit(3)
                          .pluck('categories.id')
    
    preference_categories = Category.where(id: saved_categories)
    
    # Get categories that match user's goals
    goal_categories = if user.goals&.any?
                       Category.where('name ILIKE ANY (ARRAY[?])', user.goals.map { |goal| "%#{goal}%" })
                              .limit(2)
                     else
                       Category.none
                     end
    
    # Fill in with popular categories if needed
    popular_categories = Category.joins(:tips)
                                .group('categories.id')
                                .order('count(tips.id) desc')
                                .limit(5)
    
    # Combine and ensure uniqueness
    all_categories = (preference_categories.to_a + goal_categories.to_a + popular_categories.to_a).uniq
    
    # Return at least 3 categories, preferring user's preferences
    all_categories.any? ? all_categories : Category.limit(3).to_a
  end
  
  def build_context_for_user(user, category)
    recent_saves = user.saved_tip_items
                      .joins(:category)
                      .where(categories: { id: category.id })
                      .order(created_at: :desc)
                      .limit(3)
                      .pluck(:title)
    
    {
      recent_saves: recent_saves,
      time_of_day: determine_time_of_day,
      category_engagement: user.saved_tip_items.joins(:category).where(categories: { id: category.id }).count
    }
  end
  
  def determine_time_of_day
    hour = Time.current.hour
    case hour
    when 5..11 then 'morning'
    when 12..17 then 'afternoon'
    when 18..21 then 'evening'
    else 'night'
    end
  end
  
  def create_ai_tip(user, category, tip_data)
    # Create tip authored by a system user or the requesting user
    system_user = User.find_by(email_address: 'system@personalgolf.app') || user
    
    Tip.create!(
      title: tip_data[:title],
      content: tip_data[:content],
      user: system_user,
      category: category,
      phase: tip_data[:phase] || 'during_round',
      skill_level: user.skill_level || 'beginner',
      ai_generated: true,
      published: true
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to create AI tip for user #{user.id}: #{e.message}"
    Rails.logger.error "Tip data: #{tip_data.inspect}"
    nil
  end
  
  def broadcast_new_tips_notification(user, count)
    # Send a Turbo Stream notification if the user is online
    user.broadcast_append_to(
      "user_#{user.id}",
      target: "notifications",
      html: notification_html(count)
    )
  rescue => e
    # Fail silently if broadcast fails (user might be offline)
    Rails.logger.debug "Failed to broadcast notification to user #{user.id}: #{e.message}"
  end
  
  def notification_html(count)
    <<~HTML
      <div class="notification bg-golf-green-100 border border-golf-green-300 text-golf-green-800 px-4 py-2 rounded-lg mb-2">
        <span class="font-medium">🎯 #{count} new personalized tip#{'s' if count != 1} generated!</span>
        <button onclick="this.parentElement.remove()" class="float-right text-golf-green-600 hover:text-golf-green-800">×</button>
      </div>
    HTML
  end
end