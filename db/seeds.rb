# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create categories
categories = [
  { name: 'Basics', slug: 'basics', description: 'Fundamental golf tips for all skill levels' },
  { name: 'Driving', slug: 'driving', description: 'Tips for tee shots and distance' },
  { name: 'Putting', slug: 'putting', description: 'Master the art of putting' },
  { name: 'Short Game', slug: 'short-game', description: 'Chipping, pitching, and bunker play' },
  { name: 'Mental Game', slug: 'mental-game', description: 'Psychology and focus techniques' },
  { name: 'Course Management', slug: 'course-management', description: 'Strategic play and decision making' },
  { name: 'Practice', slug: 'practice', description: 'Effective practice routines and drills' }
].map do |cat_data|
  Category.find_or_create_by(slug: cat_data[:slug]) do |category|
    category.name = cat_data[:name]
    category.description = cat_data[:description]
  end
end

# Create a demo user for development
if Rails.env.development?
  demo_user = User.find_or_create_by(email_address: 'demo@example.com') do |user|
    user.password = 'password123'
    user.name = 'Demo Golfer'
    user.skill_level = 'intermediate'
    user.handicap = 18
    user.goals = ['lower_scores', 'consistency']
    user.onboarding_completed = true
  end

  # Load tips from YAML files
  def load_tips_from_files(demo_user, categories)
    tip_files = [
      'db/sample_data/tips.yml',
      'db/sample_data/tips_advanced.yml'
      # Add more files as needed: 'db/sample_data/tips_pro.yml', etc.
    ]
    
    total_tips_created = 0
    
    tip_files.each do |file_path|
      next unless File.exist?(file_path)
      
      tips_data = YAML.load_file(file_path)
      
      tips_data.each do |category_slug, tips|
        category = categories.find { |c| c.slug == category_slug.gsub('_', '-') }
        next unless category
        
        tips.each_with_index do |tip_data, index|
          tip = Tip.find_or_create_by(title: tip_data['title']) do |t|
            t.content = tip_data['content']
            t.user = demo_user
            t.category = category
            t.phase = tip_data['phase']
            t.skill_level = tip_data['skill_level']
            t.published = true
            t.ai_generated = index % 4 == 0 # Mark some as AI generated
            t.save_count = rand(0..100)
          end
          
          total_tips_created += 1 if tip.persisted?
        end
      end
    end
    
    total_tips_created
  end

  # Create tips from YAML files
  tips_created = load_tips_from_files(demo_user, categories)

  puts "✅ Created #{Category.count} categories and #{tips_created} tips"
  puts "✅ Total tips in database: #{Tip.count}"
  puts "✅ Demo user: demo@example.com / password123"
end