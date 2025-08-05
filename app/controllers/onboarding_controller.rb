class OnboardingController < ApplicationController
  allow_unauthenticated_access only: [:welcome]
  before_action :ensure_onboarding_not_completed, except: [:welcome]
  
  def welcome
    # Check authentication status (this will resume the session)
    if authenticated?
      if current_user.onboarding_completed?
        redirect_to tips_path
      else
        redirect_to onboarding_skill_level_path
      end
    end
  end

  def skill_level
    @user = current_user
  end

  def update_skill_level
    if current_user.update(skill_level_params)
      redirect_to onboarding_goals_path
    else
      render :skill_level, status: :unprocessable_entity
    end
  end

  def goals
    @user = current_user
  end

  def update_goals
    if current_user.update(goals_params)
      redirect_to onboarding_first_tip_path
    else
      render :goals, status: :unprocessable_entity
    end
  end

  def first_tip
    @first_tip = generate_first_tip_for_user
  end

  def save_first_tip
    tip = Tip.find(params[:tip_id])
    current_user.save_tip(tip)
    current_user.update(onboarding_completed: true)
    
    redirect_to tips_path, notice: "Welcome to Personal Golf! Your first tip has been saved."
  end

  private

  def ensure_onboarding_not_completed
    redirect_to tips_path if current_user.onboarding_completed?
  end

  def skill_level_params
    params.require(:user).permit(:skill_level, :name, :handicap)
  end

  def goals_params
    params.require(:user).permit(goals: [])
  end

  def generate_first_tip_for_user
    # For now, find or create a beginner-friendly tip
    # Later this will call the AI service
    tip = Tip.published
             .for_skill_level(current_user.skill_level || 'beginner')
             .by_category(Category.find_by(slug: 'basics'))
             .first

    if tip.nil?
      # Create a default tip if none exists
      category = Category.find_or_create_by(name: 'Basics') do |c|
        c.description = 'Fundamental golf tips for all skill levels'
      end

      tip = Tip.create!(
        title: "Master Your Grip Pressure",
        content: "Hold the club like you're holding a tube of toothpaste with the cap off - firm enough to control it, but gentle enough not to squeeze any out. This promotes better club control and more consistent shots.",
        user: User.first || current_user,
        category: category,
        phase: 'during_round',
        skill_level: current_user.skill_level || 'beginner',
        published: true,
        ai_generated: true
      )
    end

    tip
  end
end