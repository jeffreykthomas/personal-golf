# Data Flow Architecture

## Overview

The Personal Golf app built with **Rails 8** uses a simplified data flow architecture leveraging SQLite as the primary database with the Solid trifecta handling background jobs, caching, and real-time communication. This design eliminates external dependencies while maintaining high performance and real-time capabilities.

## Database Architecture

### Single SQLite Database Design

```sql
-- Core application tables
CREATE TABLE users (
  id INTEGER PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  password_digest TEXT NOT NULL,
  name TEXT,
  handicap INTEGER,
  skill_level INTEGER DEFAULT 0,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL
);

CREATE TABLE sessions (
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL,
  token TEXT UNIQUE NOT NULL,
  created_at DATETIME NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE tips (
  id INTEGER PRIMARY KEY,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  user_id INTEGER NOT NULL,
  category_id INTEGER NOT NULL,
  phase INTEGER DEFAULT 1,
  skill_level INTEGER DEFAULT 0,
  save_count INTEGER DEFAULT 0,
  ai_generated BOOLEAN DEFAULT FALSE,
  published BOOLEAN DEFAULT TRUE,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (category_id) REFERENCES categories(id)
);

-- Solid Queue tables (auto-generated)
CREATE TABLE solid_queue_jobs (
  id INTEGER PRIMARY KEY,
  queue_name TEXT NOT NULL,
  class_name TEXT NOT NULL,
  arguments TEXT,
  priority INTEGER DEFAULT 0,
  scheduled_at DATETIME,
  created_at DATETIME NOT NULL
);

-- Solid Cache tables (auto-generated)
CREATE TABLE solid_cache_entries (
  id INTEGER PRIMARY KEY,
  key TEXT UNIQUE NOT NULL,
  value BLOB,
  created_at DATETIME NOT NULL,
  expires_at DATETIME
);

-- Solid Cable tables (auto-generated)
CREATE TABLE solid_cable_messages (
  id INTEGER PRIMARY KEY,
  channel TEXT NOT NULL,
  payload TEXT NOT NULL,
  created_at DATETIME NOT NULL
);
```

### Rails Models and Relationships

```ruby
class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :tips, dependent: :destroy
  has_many :saves, dependent: :destroy
  has_many :saved_tips, through: :saves, source: :tip
  
  validates :email, presence: true, uniqueness: true
  normalizes :email, with: ->(email) { email.strip.downcase }
  
  enum skill_level: { beginner: 0, intermediate: 1, advanced: 2 }
end

class Tip < ApplicationRecord
  belongs_to :user
  belongs_to :category
  has_many :saves, dependent: :destroy, counter_cache: :save_count
  has_many :saved_by_users, through: :saves, source: :user
  has_many_attached :images
  
  validates :title, :content, presence: true
  
  enum phase: { pre_round: 0, during_round: 1, post_round: 2 }
  enum skill_level: { beginner: 0, intermediate: 1, advanced: 2 }
  
  # Real-time broadcasts
  broadcasts_to :category, inserts_by: :prepend
  broadcasts_to lambda { "user_#{user_id}" }, inserts_by: :prepend
  
  # Background processing
  after_create_commit :process_tip_async
  after_update_commit :update_analytics_async
  
  private
  
  def process_tip_async
    ProcessNewTipJob.perform_later(id) if ai_generated?
    UpdateRelevanceScoreJob.perform_later(id)
  end
end

class Save < ApplicationRecord
  belongs_to :user
  belongs_to :tip, counter_cache: :save_count
  
  validates :user_id, uniqueness: { scope: :tip_id }
  
  after_create_commit :broadcast_save
  
  private
  
  def broadcast_save
    tip.broadcast_replace_to tip.category, target: "tip_#{tip.id}_saves"
  end
end
```

## Data Flow Patterns

### 1. User Registration & Authentication

```ruby
# Registration flow
def create_user_flow
  # 1. User submits registration form
  user_params = params.require(:user).permit(:email, :password, :name, :handicap)
  
  # 2. Create user with Rails 8 authentication
  user = User.new(user_params)
  
  if user.save
    # 3. Create session
    session = user.sessions.create!
    cookies.signed.permanent[:session_token] = session.token
    
    # 4. Background job for welcome email
    WelcomeEmailJob.perform_later(user.id)
    
    # 5. Initialize user preferences
    InitializeUserPreferencesJob.perform_later(user.id)
    
    redirect_to root_path
  else
    render :new, status: :unprocessable_entity
  end
end
```

### 2. Tip Creation & Real-time Distribution

```ruby
# Tip creation flow with real-time updates
class TipsController < ApplicationController
  def create
    @tip = current_user.tips.build(tip_params)
    
    if @tip.save
      # Immediate response to user
      respond_to do |format|
        format.html { redirect_to @tip }
        format.turbo_stream { 
          render turbo_stream: turbo_stream.prepend("tips", @tip) 
        }
      end
      
      # Background processing (via Solid Queue)
      ProcessNewTipJob.perform_later(@tip.id)
      
      # Real-time broadcast to category subscribers (via Solid Cable)
      @tip.broadcast_append_to @tip.category
      
    else
      render :new, status: :unprocessable_entity
    end
  end
end

# Background job processing
class ProcessNewTipJob < ApplicationJob
  queue_as :tip_processing
  
  def perform(tip_id)
    tip = Tip.find(tip_id)
    
    # AI content analysis
    if tip.ai_generated?
      AnalyzeAIContentJob.perform_later(tip_id)
    else
      # Human content moderation
      ModerateTipContentJob.perform_later(tip_id)
    end
    
    # Update search index
    UpdateSearchIndexJob.perform_later(tip_id)
    
    # Notify interested users
    NotifyInterestedUsersJob.perform_later(tip_id)
  end
end
```

### 3. AI Tip Generation Pipeline

```ruby
# AI generation request flow
class AiController < ApplicationController
  def generate_tip
    # 1. Validate request
    category = Category.find(params[:category_id])
    context = build_context_from_params
    
    # 2. Queue AI generation job
    job = GeneratePersonalizedTipJob.perform_later(
      current_user.id,
      category.id,
      context
    )
    
    # 3. Return job ID for status polling
    render json: { job_id: job.job_id, status: 'queued' }
  end
  
  def generation_status
    job = SolidQueue::Job.find_by(id: params[:job_id])
    
    render json: {
      status: job&.status || 'not_found',
      result: job&.finished? ? job.result : nil
    }
  end
end

# AI generation job
class GeneratePersonalizedTipJob < ApplicationJob
  queue_as :ai_generation
  
  def perform(user_id, category_id, context)
    user = User.find(user_id)
    category = Category.find(category_id)
    
    # 1. Build user profile for AI
    profile = {
      handicap: user.handicap,
      skill_level: user.skill_level,
      preferences: user.preferences.to_h,
      recent_saves: user.saves.recent.includes(:tip).limit(10)
    }
    
    # 2. Call Gemini API
    tip_data = GeminiService.generate_tip(
      profile: profile,
      category: category.name,
      context: context
    )
    
    # 3. Create tip
    tip = user.tips.create!(
      title: tip_data[:title],
      content: tip_data[:content],
      category: category,
      ai_generated: true,
      phase: tip_data[:phase] || 'during_round'
    )
    
    # 4. Real-time notification to user
    tip.broadcast_append_to "user_#{user.id}", target: "generated_tips"
    
    # 5. Cache popular AI responses
    Rails.cache.write("ai_tip_#{category.id}_#{profile.hash}", tip_data, expires_in: 1.day)
    
    { tip_id: tip.id, status: 'completed' }
  end
end
```

### 4. Offline Data Synchronization

```javascript
// Service Worker for offline support
class OfflineDataManager {
  constructor() {
    this.dbName = 'personal_golf_offline';
    this.version = 1;
  }
  
  // Store data for offline access
  async storeForOffline(type, data) {
    const db = await this.openDB();
    const transaction = db.transaction([type], 'readwrite');
    const store = transaction.objectStore(type);
    
    if (Array.isArray(data)) {
      data.forEach(item => store.put(item));
    } else {
      store.put(data);
    }
  }
  
  // Queue offline actions
  async queueOfflineAction(action) {
    const db = await this.openDB();
    const transaction = db.transaction(['offline_actions'], 'readwrite');
    const store = transaction.objectStore('offline_actions');
    
    store.add({
      ...action,
      timestamp: Date.now(),
      synced: false
    });
  }
  
  // Sync when back online
  async syncOfflineActions() {
    const db = await this.openDB();
    const transaction = db.transaction(['offline_actions'], 'readonly');
    const store = transaction.objectStore('offline_actions');
    const unsynced = await store.getAll();
    
    for (const action of unsynced.filter(a => !a.synced)) {
      try {
        await this.executeAction(action);
        await this.markAsSynced(action.id);
      } catch (error) {
        console.error('Sync failed for action:', action, error);
      }
    }
  }
}
```

### 5. Caching Strategy with Solid Cache

```ruby
# Multi-level caching strategy
class TipsController < ApplicationController
  def index
    # 1. Try fragment cache first
    cache_key = "tips_index_#{filter_params.to_param}_#{current_user&.id}"
    
    @tips = Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
      # 2. Database query with includes
      tips = Tip.includes(:user, :category, :saves)
                .published
                .filter_by(filter_params)
                .order(relevance_score: :desc, created_at: :desc)
                .limit(20)
      
      # 3. Serialize for cache
      tips.map { |tip| tip.attributes.merge(
        user_name: tip.user.name,
        category_name: tip.category.name,
        save_count: tip.saves.count
      )}
    end
    
    # 4. Convert back to objects for view
    @tips = @tips.map { |attrs| Tip.new(attrs) }
  end
  
  def show
    # Individual tip caching
    @tip = Rails.cache.fetch("tip_#{params[:id]}", expires_in: 1.hour) do
      Tip.includes(:user, :category, :saves, images_attachments: :blob)
         .find(params[:id])
    end
  end
end

# Cache invalidation
class Tip < ApplicationRecord
  after_update_commit :invalidate_caches
  after_destroy_commit :invalidate_caches
  
  private
  
  def invalidate_caches
    # Invalidate related caches
    Rails.cache.delete("tip_#{id}")
    Rails.cache.delete_matched("tips_index_*")
    Rails.cache.delete_matched("category_#{category_id}_*")
  end
end
```

### 6. Real-time Update Flow

```ruby
# Real-time updates via Solid Cable
class TipInteractionChannel < ApplicationCable::Channel
  def subscribed
    # Subscribe to category updates
    stream_from "category_#{params[:category_id]}" if params[:category_id]
    
    # Subscribe to personal updates
    stream_from "user_#{current_user.id}"
  end
  
  def save_tip(data)
    tip = Tip.find(data['tip_id'])
    save = current_user.saves.create!(tip: tip)
    
    if save.persisted?
      # Update tip save count
      tip.increment!(:save_count)
      
      # Broadcast to all category subscribers
      ActionCable.server.broadcast "category_#{tip.category_id}", {
        type: 'tip_saved',
        tip_id: tip.id,
        save_count: tip.save_count,
        user_id: current_user.id
      }
      
      # Update user's personal feed
      broadcast_to current_user, {
        type: 'tip_saved_confirmation',
        tip_id: tip.id
      }
    end
  end
end
```

## Performance Optimization

### Database Indexes

```ruby
class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    # Core query indexes
    add_index :tips, [:category_id, :published, :created_at]
    add_index :tips, [:user_id, :created_at]
    add_index :tips, :save_count
    add_index :tips, [:phase, :skill_level]
    
    # Search indexes
    add_index :tips, :title
    add_index :tips, :content  # For FTS if needed
    
    # Relationship indexes
    add_index :saves, [:user_id, :tip_id], unique: true
    add_index :saves, [:tip_id, :created_at]
    
    # Solid Queue performance
    add_index :solid_queue_jobs, [:queue_name, :scheduled_at]
    add_index :solid_queue_jobs, :created_at
    
    # Solid Cache performance
    add_index :solid_cache_entries, :expires_at
    add_index :solid_cache_entries, :created_at
  end
end
```

### Query Optimization

```ruby
# Efficient queries with proper includes
class Tip < ApplicationRecord
  scope :with_associations, -> { includes(:user, :category, :saves) }
  scope :popular_in_timeframe, ->(days = 7) do
    joins(:saves)
      .where(saves: { created_at: days.days.ago.. })
      .group(:id)
      .order('COUNT(saves.id) DESC')
  end
  
  # Efficient counter queries
  def self.popular_with_save_counts
    select('tips.*, COUNT(saves.id) as saves_count')
      .left_joins(:saves)
      .group('tips.id')
      .order('saves_count DESC')
  end
end
```

This data flow architecture leverages Rails 8's Solid trifecta to create a simple yet powerful system that handles real-time updates, background processing, and efficient caching without external dependencies while maintaining excellent performance characteristics.