# User Experience & Onboarding Guide

## Philosophy

The Personal Golf app follows the principle of **progressive disclosure** - showing users only what they need when they need it, while making advanced features discoverable as they grow comfortable with the app. Inspired by focus apps like Opal, we prioritize clarity, simplicity, and golf-specific workflows.

## Core UX Principles

### 1. Golf-First Mindset
- **On-Course Focus**: Quick access to essential tips during play
- **Context Awareness**: Show relevant content based on time, weather, location
- **Skill Progression**: Adapt content complexity to user skill level
- **Practice Integration**: Connect course play with practice routines

### 2. Progressive Disclosure
- **Start Simple**: New users see only essential features
- **Guided Discovery**: Help users find features naturally through use
- **Contextual Revelation**: Introduce advanced features when relevant
- **Smart Defaults**: Everything works beautifully out of the box

### 3. Mobile-First Excellence
- **Thumb-Friendly**: All interactions within comfortable reach
- **Glanceable Information**: Quick reads for on-course usage
- **Offline Resilience**: Core features work without connectivity
- **Battery Consciousness**: Minimal resource usage

### 4. Community-Driven Learning
- **Peer Wisdom**: Highlight tips from similar skill levels
- **Local Knowledge**: Prioritize course-specific insights
- **Social Validation**: Show what's working for others
- **Contribution Incentives**: Make sharing knowledge rewarding

## Rails 8 Implementation Strategy

### Hotwire-Powered Progressive Disclosure

```erb
<!-- Progressive content loading with Turbo Frames -->
<%= turbo_frame_tag "user_journey", 
    src: onboarding_step_path(current_step), 
    class: "min-h-screen" do %>
  
  <!-- Loading state with golf ball animation -->
  <div class="flex items-center justify-center min-h-screen">
    <%= render "shared/golf_ball_loader" %>
  </div>
<% end %>
```

### Stimulus-Enhanced Interactions

```javascript
// Smart onboarding with contextual help
// app/javascript/controllers/onboarding_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["step", "progress", "skipButton"]
  static values = { 
    currentStep: Number,
    totalSteps: Number,
    userPath: String 
  }

  connect() {
    this.updateProgress()
    this.trackUserBehavior()
  }

  nextStep() {
    if (this.currentStepValue < this.totalStepsValue) {
      this.currentStepValue++
      this.loadStep()
    } else {
      this.completeOnboarding()
    }
  }

  skipToValue() {
    // Intelligent skip that preserves user preferences
    this.savePartialProgress()
    this.completeOnboarding()
  }

  loadStep() {
    // Use Turbo to load next step without full page refresh
    Turbo.visit(`/onboarding/step/${this.currentStepValue}`, {
      frame: "onboarding_content"
    })
  }
}
```

## Onboarding Flow

### Step 1: Welcome & Value Proposition

```erb
<!-- app/views/onboarding/welcome.html.erb -->
<div class="min-h-screen bg-dark-bg flex flex-col items-center justify-center px-6 text-center"
     data-controller="onboarding" 
     data-onboarding-current-step-value="1"
     data-onboarding-total-steps-value="3">

  <!-- Skip button -->
  <button class="absolute top-6 right-6 text-gray-400 hover:text-white transition-colors"
          data-action="click->onboarding#skipToValue">
    Skip
  </button>

  <!-- Golf ball hero animation -->
  <div class="golf-ball-orb mb-8" data-controller="golf-ball" data-golf-ball-progress-value="0">
    <div class="golf-ball-dimples"></div>
    
    <!-- Animated intro sequence -->
    <div class="absolute inset-0 flex items-center justify-center">
      <svg class="w-16 h-16 text-golf-green-500 animate-pulse" fill="currentColor" viewBox="0 0 24 24">
        <path d="M12 2L2 7v10c0 5.55 3.84 9.739 9 9.949V27L22 17V7l-10-5zm0 2.236L19.382 8 12 11.764 4.618 8 12 4.236zM4 9.236l7 3.764v7.764C6.654 20.455 4 17.14 4 12.764V9.236zm16 3.528c0 4.376-2.654 7.691-7 8V13l7-3.764v3.528z"/>
      </svg>
    </div>
  </div>

  <!-- Value proposition -->
  <h1 class="text-hero mb-4">Your Pocket Golf Coach</h1>
  <p class="text-body mb-8 max-w-sm">
    Discover personalized tips, track your progress, and learn from golfers like you.
  </p>

  <!-- CTA -->
  <button class="w-full max-w-xs bg-golf-green-500 hover:bg-golf-green-600 text-dark-bg font-semibold py-4 px-6 rounded-2xl transition-colors"
          data-action="click->onboarding#nextStep">
    Get Started
  </button>

  <!-- Progress indicator -->
  <div class="flex space-x-2 mt-8">
    <div class="w-3 h-3 bg-golf-green-500 rounded-full"></div>
    <div class="w-3 h-3 bg-gray-600 rounded-full"></div>
    <div class="w-3 h-3 bg-gray-600 rounded-full"></div>
  </div>
</div>
```

### Step 2: Skill Level & Goals

```erb
<!-- app/views/onboarding/skill_level.html.erb -->
<div class="min-h-screen bg-dark-bg px-6 py-12"
     data-controller="skill-selector">

  <div class="max-w-md mx-auto">
    <h2 class="text-title mb-2 text-center">What's your skill level?</h2>
    <p class="text-body text-center mb-8">We'll personalize tips for your game</p>

    <!-- Skill level options -->
    <div class="space-y-4">
      <% %w[beginner intermediate advanced].each_with_index do |level, index| %>
        <button class="w-full bg-dark-card border border-dark-border rounded-2xl p-6 text-left transition-all duration-300 hover:border-golf-green-500/50"
                data-action="click->skill-selector#select"
                data-skill-selector-level-value="<%= level %>"
                data-skill-selector-target="option">
          
          <div class="flex items-center justify-between">
            <div>
              <h3 class="text-heading mb-1"><%= level.humanize %></h3>
              <p class="text-caption">
                <% case level %>
                <% when 'beginner' %>
                  New to golf or playing for less than 2 years
                <% when 'intermediate' %>
                  Regular player, handicap 15-25
                <% when 'advanced' %>
                  Low handicap player, competing regularly
                <% end %>
              </p>
            </div>
            
            <!-- Selection indicator -->
            <div class="w-6 h-6 border-2 border-gray-500 rounded-full flex items-center justify-center"
                 data-skill-selector-target="indicator">
              <div class="w-3 h-3 bg-golf-green-500 rounded-full hidden"
                   data-skill-selector-target="selected"></div>
            </div>
          </div>
        </button>
      <% end %>
    </div>

    <!-- Goals selection -->
    <div class="mt-8">
      <h3 class="text-heading mb-4">What's your main goal?</h3>
      
      <%= form_with model: current_user, 
          url: onboarding_goals_path, 
          local: false,
          data: { 
            controller: "form-submission",
            action: "submit->form-submission#submit"
          } do |f| %>
        
        <div class="space-y-3">
          <% ['Lower my scores', 'Play more consistently', 'Learn proper technique', 'Enjoy the game more'].each do |goal| %>
            <label class="flex items-center space-x-3 cursor-pointer">
              <%= f.check_box :goals, 
                  { multiple: true, class: "sr-only" }, 
                  goal, 
                  nil %>
              <div class="w-5 h-5 border-2 border-gray-500 rounded flex items-center justify-center">
                <svg class="w-3 h-3 text-golf-green-500 hidden" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z"/>
                </svg>
              </div>
              <span class="text-body"><%= goal %></span>
            </label>
          <% end %>
        </div>

        <!-- Continue button -->
        <button type="submit" 
                class="w-full mt-8 bg-golf-green-500 hover:bg-golf-green-600 text-dark-bg font-semibold py-4 px-6 rounded-2xl transition-colors">
          Continue
        </button>
      <% end %>
    </div>
  </div>
</div>
```

### Step 3: First Win - Immediate Value

```erb
<!-- app/views/onboarding/first_tip.html.erb -->
<div class="min-h-screen bg-dark-bg px-6 py-12">
  <div class="max-w-md mx-auto">
    
    <div class="text-center mb-8">
      <h2 class="text-title mb-2">Here's your first tip!</h2>
      <p class="text-body">Based on your skill level, this should help immediately</p>
    </div>

    <!-- Personalized tip card -->
    <%= turbo_frame_tag "personalized_tip" do %>
      <div class="bg-dark-card rounded-2xl p-6 border border-golf-green-500/30 mb-8"
           data-controller="tip-card"
           data-tip-card-tip-id-value="<%= @first_tip.id %>">
        
        <!-- AI Generated badge -->
        <div class="flex items-center space-x-2 mb-4">
          <div class="w-3 h-3 bg-accent-blue rounded-full"></div>
          <span class="text-caption">Personalized for you</span>
        </div>

        <!-- Tip content -->
        <h3 class="text-heading mb-3"><%= @first_tip.title %></h3>
        <p class="text-body leading-relaxed mb-6"><%= @first_tip.content %></p>

        <!-- Quick action -->
        <button class="w-full bg-golf-green-500 hover:bg-golf-green-600 text-dark-bg font-semibold py-3 px-6 rounded-xl transition-colors"
                data-action="click->tip-card#saveAndContinue">
          Save This Tip & Continue
        </button>
      </div>
    <% end %>

    <!-- Encouragement -->
    <div class="text-center">
      <p class="text-caption mb-4">Great choice! You'll find this and other saved tips in your collection.</p>
      
      <%= link_to tips_path, 
          class: "text-golf-green-500 hover:text-golf-green-400 transition-colors font-medium" do %>
        Explore More Tips →
      <% end %>
    </div>
  </div>
</div>
```

## Progressive Disclosure Patterns

### Contextual Feature Introduction

```erb
<!-- Smart feature introduction based on user behavior -->
<%= turbo_frame_tag "feature_hint", class: "relative" do %>
  <% if should_show_hint?(:course_tips, current_user) %>
    <div class="absolute -top-2 -right-2 z-10"
         data-controller="feature-hint"
         data-feature-hint-feature-value="course_tips">
      
      <!-- Pulsing indicator -->
      <div class="w-3 h-3 bg-golf-green-500 rounded-full animate-ping"></div>
      
      <!-- Tooltip on tap -->
      <div class="hidden absolute bottom-full right-0 mb-2 w-48 bg-dark-surface border border-dark-border rounded-lg p-3 shadow-lg"
           data-feature-hint-target="tooltip">
        <p class="text-caption mb-2">💡 Pro tip!</p>
        <p class="text-body text-xs">Add course-specific tips with photos to help other golfers</p>
        
        <button class="text-golf-green-500 text-xs mt-2 hover:text-golf-green-400"
                data-action="click->feature-hint#dismiss">
          Got it
        </button>
      </div>
    </div>
  <% end %>
<% end %>
```

### Adaptive Navigation

```erb
<!-- Navigation that grows with user expertise -->
<div class="bottom-navigation" 
     data-controller="adaptive-nav"
     data-adaptive-nav-user-level-value="<%= current_user.experience_level %>">
  
  <!-- Core tabs always visible -->
  <%= link_to tips_path, class: nav_classes('tips') do %>
    <svg class="w-6 h-6 mb-1"><!-- icon --></svg>
    <span class="text-xs">Tips</span>
  <% end %>

  <!-- Advanced features unlock progressively -->
  <% if current_user.experienced? %>
    <%= link_to analytics_path, class: nav_classes('analytics') do %>
      <svg class="w-6 h-6 mb-1"><!-- chart icon --></svg>
      <span class="text-xs">Stats</span>
    <% end %>
  <% end %>

  <!-- FAB adapts to context -->
  <button class="fab-button bg-golf-green-500"
          data-adaptive-nav-target="fab"
          data-action="click->adaptive-nav#showContextMenu">
    <svg class="w-6 h-6">
      <!-- Icon changes based on context -->
      <%= current_user.on_course? ? "add_location" : "add" %>
    </svg>
  </button>
</div>
```

## Mobile-First Design Patterns

### Thumb-Friendly Interactions

```erb
<!-- All interactive elements within thumb reach -->
<div class="thumb-zone">
  <!-- Safe zone: bottom 70% of screen on average phone -->
  
  <!-- Primary actions in natural thumb arc -->
  <div class="flex justify-between items-center p-4">
    <button class="w-12 h-12 rounded-full bg-dark-surface flex items-center justify-center">
      <!-- Back button in comfortable reach -->
    </button>
    
    <div class="flex space-x-3">
      <!-- Action buttons in thumb sweep area -->
      <button class="w-12 h-12 rounded-full bg-golf-green-500">Save</button>
      <button class="w-12 h-12 rounded-full bg-dark-surface">Share</button>
    </div>
  </div>
</div>
```

### Gesture-Friendly Cards

```javascript
// app/javascript/controllers/swipe_card_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card"]
  static values = { 
    tipId: Number,
    threshold: { type: Number, default: 100 }
  }

  connect() {
    this.startX = 0
    this.currentX = 0
    this.cardTarget.addEventListener('touchstart', this.handleTouchStart.bind(this))
    this.cardTarget.addEventListener('touchmove', this.handleTouchMove.bind(this))
    this.cardTarget.addEventListener('touchend', this.handleTouchEnd.bind(this))
  }

  handleTouchStart(event) {
    this.startX = event.touches[0].clientX
  }

  handleTouchMove(event) {
    if (!this.startX) return
    
    this.currentX = event.touches[0].clientX
    const deltaX = this.currentX - this.startX
    
    // Visual feedback during swipe
    this.cardTarget.style.transform = `translateX(${deltaX}px)`
    this.cardTarget.style.opacity = 1 - Math.abs(deltaX) / 200
  }

  handleTouchEnd(event) {
    const deltaX = this.currentX - this.startX
    
    if (Math.abs(deltaX) > this.thresholdValue) {
      // Complete the swipe action
      if (deltaX > 0) {
        this.saveTrip()
      } else {
        this.skipTip()
      }
    } else {
      // Snap back to original position
      this.resetCard()
    }
  }

  saveTrip() {
    // Animate off screen then save
    this.cardTarget.style.transform = 'translateX(100%)'
    this.cardTarget.style.opacity = '0'
    
    setTimeout(() => {
      fetch(`/tips/${this.tipIdValue}/save`, { method: 'POST' })
      this.showFeedback('Saved! 💚')
    }, 200)
  }

  skipTip() {
    // Animate off screen
    this.cardTarget.style.transform = 'translateX(-100%)'
    this.cardTarget.style.opacity = '0'
    
    setTimeout(() => {
      this.element.remove()
    }, 200)
  }

  resetCard() {
    this.cardTarget.style.transform = 'translateX(0)'
    this.cardTarget.style.opacity = '1'
  }
}
```

## Contextual Help System

### Smart Onboarding Tooltips

```erb
<!-- Help system that appears contextually -->
<div class="relative" data-controller="contextual-help" data-contextual-help-feature-value="tip_saving">
  
  <!-- Main feature -->
  <button class="save-button" data-action="click->contextual-help#triggerIfFirstTime">
    Save Tip
  </button>

  <!-- Contextual help overlay -->
  <div class="hidden fixed inset-0 bg-black/50 z-50 flex items-center justify-center"
       data-contextual-help-target="overlay">
    
    <div class="bg-dark-surface rounded-2xl p-6 mx-6 max-w-sm">
      <h3 class="text-heading mb-3">💡 Pro Tip</h3>
      <p class="text-body mb-4">
        Saved tips appear in your collection for quick access on the course!
      </p>
      
      <div class="flex space-x-3">
        <button class="flex-1 bg-golf-green-500 text-dark-bg py-2 px-4 rounded-xl"
                data-action="click->contextual-help#dismiss">
          Got it!
        </button>
        <button class="flex-1 border border-dark-border py-2 px-4 rounded-xl"
                data-action="click->contextual-help#skipAllHelp">
          Skip hints
        </button>
      </div>
    </div>
  </div>
</div>
```

### Progressive Tip Complexity

```ruby
# app/helpers/tip_helper.rb
module TipHelper
  def tip_complexity_for_user(tip, user)
    case user.experience_level
    when 'beginner'
      tip.basic_explanation
    when 'intermediate'
      tip.detailed_explanation
    when 'advanced'
      tip.technical_details
    end
  end

  def should_show_advanced_features?(user)
    user.tips_saved_count > 10 && user.days_active > 7
  end

  def personalized_tip_categories(user)
    base_categories = %w[putting driving basics]
    
    # Add advanced categories based on engagement
    if user.experienced?
      base_categories += %w[course_management mental_game strategy]
    end
    
    base_categories
  end
end
```

## Performance & Accessibility

### Optimistic UI Updates

```javascript
// Immediate feedback while background requests process
// app/javascript/controllers/optimistic_ui_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "counter"]

  async saveTrip(event) {
    event.preventDefault()
    
    // Immediate visual feedback
    this.buttonTarget.textContent = "Saved!"
    this.buttonTarget.classList.add('bg-golf-green-600')
    this.incrementCounter()
    
    try {
      // Background request
      const response = await fetch(this.buttonTarget.dataset.url, {
        method: 'POST',
        headers: { 'X-CSRF-Token': this.csrfToken }
      })
      
      if (!response.ok) {
        // Revert optimistic update on failure
        this.revertOptimisticUpdate()
        this.showError('Save failed. Try again.')
      }
      
    } catch (error) {
      this.revertOptimisticUpdate()
      this.showError('Connection error. Saved locally.')
      this.queueForOfflineSync()
    }
  }

  incrementCounter() {
    const current = parseInt(this.counterTarget.textContent)
    this.counterTarget.textContent = current + 1
  }

  revertOptimisticUpdate() {
    this.buttonTarget.textContent = "Save Tip"
    this.buttonTarget.classList.remove('bg-golf-green-600')
    
    const current = parseInt(this.counterTarget.textContent)
    this.counterTarget.textContent = current - 1
  }
}
```

### Accessibility Enhancements

```erb
<!-- Screen reader and keyboard navigation support -->
<div class="tip-card" 
     role="article" 
     aria-labelledby="tip-title-<%= tip.id %>"
     tabindex="0"
     data-controller="a11y-card">
  
  <!-- Descriptive headings -->
  <h3 id="tip-title-<%= tip.id %>" class="text-heading">
    <%= tip.title %>
  </h3>
  
  <!-- Semantic actions -->
  <div role="group" aria-label="Tip actions">
    <button aria-label="Save <%= tip.title %> to your collection"
            data-action="click->a11y-card#save keydown.enter->a11y-card#save">
      <span aria-hidden="true">💾</span>
      Save
    </button>
    
    <button aria-label="Share <%= tip.title %>"
            data-action="click->a11y-card#share keydown.enter->a11y-card#share">
      <span aria-hidden="true">📤</span>
      Share
    </button>
  </div>

  <!-- Status announcements -->
  <div role="status" aria-live="polite" class="sr-only" data-a11y-card-target="status">
    <!-- Dynamic status updates for screen readers -->
  </div>
</div>
```

## Testing User Flows

### System Tests for Onboarding

```ruby
# test/system/onboarding_test.rb
require "application_system_test_case"

class OnboardingTest < ApplicationSystemTestCase
  test "new user completes onboarding successfully" do
    visit root_path
    
    # Step 1: Welcome
    assert_text "Your Pocket Golf Coach"
    click_button "Get Started"
    
    # Step 2: Skill level
    assert_text "What's your skill level?"
    click_button "Intermediate"
    
    # Check goal
    check "Lower my scores"
    click_button "Continue"
    
    # Step 3: First tip
    assert_text "Here's your first tip!"
    assert_selector "[data-controller='tip-card']"
    
    click_button "Save This Tip & Continue"
    
    # Should land on main tips page
    assert_current_path tips_path
    assert_text "Tips"
    
    # User should have saved tip
    assert_equal 1, User.last.saves.count
  end

  test "user can skip onboarding" do
    visit root_path
    
    click_button "Skip"
    
    # Should still create user with defaults
    assert_current_path tips_path
    assert User.exists?
  end

  test "onboarding is mobile responsive" do
    # Test on mobile viewport
    page.driver.browser.manage.window.resize_to(375, 667)
    
    visit root_path
    
    # Check mobile-specific elements
    assert_selector ".golf-ball-orb"
    assert_selector ".thumb-zone"
    
    # Ensure touch targets are adequate size
    save_button = find("button", text: "Get Started")
    assert save_button[:class].include?("py-4") # Adequate height
  end
end
```

### Stimulus Controller Tests

```javascript
// test/javascript/controllers/onboarding_controller_test.js
import { Application } from "@hotwired/stimulus"
import OnboardingController from "controllers/onboarding_controller"

describe("OnboardingController", () => {
  let application
  let controller

  beforeEach(() => {
    application = Application.start()
    application.register("onboarding", OnboardingController)
    
    document.body.innerHTML = `
      <div data-controller="onboarding" 
           data-onboarding-current-step-value="1"
           data-onboarding-total-steps-value="3">
        <button data-action="click->onboarding#nextStep">Next</button>
        <button data-action="click->onboarding#skipToValue">Skip</button>
      </div>
    `
  })

  test("advances to next step", () => {
    const nextButton = document.querySelector("[data-action*='nextStep']")
    const controller = application.getControllerForElementAndIdentifier(
      nextButton.closest("[data-controller]"), 
      "onboarding"
    )
    
    expect(controller.currentStepValue).toBe(1)
    
    nextButton.click()
    
    expect(controller.currentStepValue).toBe(2)
  })

  test("tracks user behavior", () => {
    // Mock analytics
    const analytics = jest.fn()
    window.gtag = analytics
    
    const nextButton = document.querySelector("[data-action*='nextStep']")
    nextButton.click()
    
    expect(analytics).toHaveBeenCalledWith('event', 'onboarding_step', {
      step: 2,
      user_path: undefined
    })
  })
})
```

This comprehensive user experience guide transforms your golf app into a thoughtfully designed, progressive experience that welcomes new users while growing with their expertise. The Opal-inspired design language creates a calming, focused environment perfect for learning and applying golf knowledge.