class User < ApplicationRecord
  has_secure_password validations: false
  has_many :sessions, dependent: :destroy
  has_many :tips, dependent: :destroy
  has_many :saved_tips, dependent: :destroy
  has_many :saved_tip_items, through: :saved_tips, source: :tip

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  
  # Custom validation for password (required only for email/password auth)
  validates :password, presence: true, length: { minimum: 6 }, unless: :oauth_user?

  enum :skill_level, { beginner: 0, intermediate: 1, advanced: 2 }

  serialize :goals, coder: JSON, type: Array

  scope :onboarded, -> { where(onboarding_completed: true) }

  def display_name
    name.presence || email_address.split('@').first
  end

  def save_tip(tip)
    saved_tips.find_or_create_by(tip: tip)
  end

  def saved?(tip)
    saved_tips.exists?(tip: tip)
  end

  def tips_viewed_count
    tips.count + saved_tip_items.count
  end

  def experienced?
    tips_viewed_count > 10 || created_at < 7.days.ago
  end

  def on_course?
    # Placeholder for future GPS/location integration
    false
  end

  def profile_for_ai
    {
      handicap: handicap,
      skill_level: skill_level,
      goals: goals || [],
      saved_tips_count: saved_tips.count,
      favorite_categories: favorite_categories_for_ai,
      experience_level: experience_level_for_ai,
      created_days_ago: (Date.current - created_at.to_date).to_i
    }
  end
  
  def favorite_categories_for_ai
    # Get top 3 categories from saved tips
    saved_tips.joins(:tip => :category)
              .group('categories.name')
              .order('count(categories.name) desc')
              .limit(3)
              .pluck('categories.name')
  end
  
  def experience_level_for_ai
    case
    when tips_viewed_count < 5 then 'new_user'
    when tips_viewed_count < 20 then 'casual'
    when tips_viewed_count < 50 then 'engaged'
    else 'power_user'
    end
  end
  
  def self.from_omniauth(auth)
    # First try to find existing user by email
    user = find_by(email_address: auth.info.email)
    
    if user
      # Update OAuth info for existing user
      user.update!(
        provider: auth.provider,
        uid: auth.uid,
        google_token: auth.credentials.token,
        google_refresh_token: auth.credentials.refresh_token,
        name: auth.info.name || user.name
      )
    else
      # Create new user from OAuth
      user = create!(
        email_address: auth.info.email,
        name: auth.info.name,
        provider: auth.provider,
        uid: auth.uid,
        google_token: auth.credentials.token,
        google_refresh_token: auth.credentials.refresh_token
      )
    end
    
    user
  end
  
  def oauth_user?
    provider.present? && uid.present?
  end
end
