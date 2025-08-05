# API Design

## Overview

The Personal Golf app API is built using **Ruby on Rails 8** with RESTful design principles. The API leverages Rails 8's built-in authentication, Solid trifecta for performance, and Hotwire for real-time features.

## Authentication

### Rails 8 Built-in Authentication

```ruby
# Session-based authentication endpoints
POST   /login              # Create session
DELETE /logout             # Destroy session
GET    /signup             # New user form
POST   /users              # Create user

# Password reset flow
GET    /password/reset/new     # Request reset form
POST   /password/reset         # Send reset email
GET    /password/reset/edit    # Reset form with token
PATCH  /password/reset         # Update password
```

### Authentication Middleware

```ruby
class ApplicationController < ActionController::Base
  include Authentication
  before_action :authenticate_user!, except: [:index, :show]
  
  private
  
  def current_user
    Current.user
  end
end
```

## Core API Endpoints

### Tips Management

```ruby
# RESTful tips endpoints
GET    /tips                # List tips (with filters)
GET    /tips/:id            # Show specific tip
POST   /tips                # Create new tip
PATCH  /tips/:id            # Update tip (owner only)
DELETE /tips/:id            # Delete tip (owner only)

# Tip interactions
POST   /tips/:id/save       # Save tip to collection
DELETE /tips/:id/save       # Remove from collection

# Advanced queries
GET    /tips/search         # Search tips
GET    /tips/popular        # Popular tips
GET    /tips/saved          # User's saved tips
```

### Rails Controller Examples

```ruby
class TipsController < ApplicationController
  before_action :set_tip, only: [:show, :edit, :update, :destroy]
  before_action :authenticate_user!, except: [:index, :show]
  
  def index
    @tips = Tip.includes(:user, :category)
               .filter_by_params(filter_params)
               .page(params[:page])
    
    # Cache with Solid Cache
    @tips = Rails.cache.fetch(cache_key_for_tips, expires_in: 5.minutes) do
      @tips.to_a
    end
    
    respond_to do |format|
      format.html
      format.json { render json: @tips, include: [:user, :category] }
    end
  end
  
  def create
    @tip = current_user.tips.build(tip_params)
    
    if @tip.save
      # Real-time broadcast via Turbo Stream
      @tip.broadcast_append_to @tip.category, target: "tips"
      
      # Background job for AI analysis
      AnalyzeTipJob.perform_later(@tip.id)
      
      respond_to do |format|
        format.html { redirect_to @tip, notice: 'Tip created successfully.' }
        format.json { render json: @tip, status: :created }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @tip.errors, status: :unprocessable_entity }
      end
    end
  end
  
  private
  
  def tip_params
    params.require(:tip).permit(:title, :content, :category_id, :phase, :skill_level, images: [])
  end
end
```

## Background Jobs with Solid Queue

### AI Tip Generation

```ruby
class GeneratePersonalizedTipJob < ApplicationJob
  queue_as :ai_generation
  
  def perform(user_id, category, context = {})
    user = User.find(user_id)
    
    # Generate tip using Gemini service
    tip_data = GeminiService.generate_tip(
      user_profile: user.profile_for_ai,
      category: category,
      context: context
    )
    
    # Create and broadcast tip
    tip = user.tips.create!(
      title: tip_data[:title],
      content: tip_data[:content],
      category: Category.find_by(name: category),
      ai_generated: true
    )
    
    tip.broadcast_append_to user, target: "generated_tips"
  end
end
```

## Real-Time Features with Solid Cable

### Tips Channel

```ruby
class TipsChannel < ApplicationCable::Channel
  def subscribed
    stream_from "tips_#{params[:category]}" if params[:category]
    stream_from "user_#{current_user.id}_tips"
  end
  
  def receive(data)
    case data['action']
    when 'save_tip'
      handle_save_tip(data['tip_id'])
    end
  end
  
  private
  
  def handle_save_tip(tip_id)
    tip = Tip.find(tip_id)
    save = current_user.saves.create!(tip: tip)
    
    if save.persisted?
      broadcast_to "tips_#{tip.category.name}", {
        type: 'tip_saved',
        tip_id: tip.id,
        save_count: tip.reload.save_count
      }
    end
  end
end
```

## External Services

### Gemini AI Integration

```ruby
class GeminiService
  include HTTParty
  base_uri 'https://generativelanguage.googleapis.com'
  
  def self.generate_tip(user_profile:, category:, context: {})
    prompt = build_prompt(user_profile, category, context)
    
    response = post('/v1/models/gemini-pro:generateContent',
      headers: {
        'Content-Type' => 'application/json',
        'x-goog-api-key' => Rails.application.credentials.gemini_api_key
      },
      body: {
        contents: [{ parts: [{ text: prompt }] }]
      }.to_json
    )
    
    parse_response(response)
  end
  
  private
  
  def self.build_prompt(user_profile, category, context)
    "Generate a practical golf tip for #{category}. " \
    "User handicap: #{user_profile[:handicap]}. " \
    "Provide a clear title and 2-3 sentence actionable tip."
  end
  
  def self.parse_response(response)
    content = response.dig('candidates', 0, 'content', 'parts', 0, 'text')
    lines = content.lines.map(&:strip)
    
    {
      title: lines.first || 'Golf Tip',
      content: lines[1..-1].join(' ') || content
    }
  end
end
```

## Error Handling & Rate Limiting

### Model Validations

```ruby
class Tip < ApplicationRecord
  validates :title, presence: true, length: { minimum: 5, maximum: 100 }
  validates :content, presence: true, length: { minimum: 10, maximum: 1000 }
  validates :category, :user, presence: true
  
  enum phase: { pre_round: 0, during_round: 1, post_round: 2 }
  enum skill_level: { beginner: 0, intermediate: 1, advanced: 2 }
end
```

### Rate Limiting

```ruby
class ApplicationController < ActionController::Base
  rate_limit to: 100, within: 1.minute, only: [:create, :update]
  rate_limit to: 10, within: 1.minute, only: [:ai_generate]
end
```

## Testing

### Controller Tests

```ruby
class TipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @tip = tips(:one)
    sign_in @user
  end
  
  test "should create tip" do
    assert_difference('Tip.count') do
      post tips_url, params: { 
        tip: { 
          title: 'New Tip', 
          content: 'Great advice here',
          category_id: categories(:putting).id
        } 
      }
    end
    
    assert_redirected_to tip_url(Tip.last)
  end
  
  test "should save tip via API" do
    assert_difference('@user.saves.count') do
      post save_tip_url(@tip), xhr: true
    end
    
    assert_response :success
  end
end
```

This API design leverages Rails 8's conventions and built-in features to provide a robust, scalable foundation for the Personal Golf app with real-time updates, efficient background processing, and modern authentication.