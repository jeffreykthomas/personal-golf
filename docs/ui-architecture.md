# UI Architecture

## Overview

This document outlines the UI architecture for Personal Golf PWA built with **Rails 8 + Hotwire + Tailwind CSS**. The design is inspired by modern focus/wellness apps like Opal, emphasizing clean, mobile-first design with golf-specific adaptations.

## Design System Inspiration

Drawing inspiration from the Opal app's clean, focused interface:

- **Dark theme** with excellent contrast for outdoor golf course usage
- **Bright green accents** (#22c55e) that align with golf's natural theme
- **Circular/orb design elements** adapted for golf (golf balls, course layouts)
- **Mobile-first approach** for on-course usage
- **Clean typography and generous spacing**
- **Card-based information architecture**
- **Social/community elements** for knowledge sharing

## Rails 8 + Hotwire Architecture

### Directory Structure

```
app/
├── views/
│   ├── layouts/              # Application layouts
│   │   ├── application.html.erb    # Main layout
│   │   ├── mobile.html.erb         # Mobile-optimized layout
│   │   └── auth.html.erb           # Authentication layout
│   ├── components/           # Shared view components
│   │   ├── ui/              # Base UI components
│   │   ├── tips/            # Tip-related components
│   │   ├── courses/         # Course components
│   │   └── social/          # Social/sharing components
│   ├── tips/                # Tip views
│   ├── courses/            # Course views
│   ├── users/              # User profile views
│   └── shared/             # Shared partials
├── javascript/
│   ├── controllers/        # Stimulus controllers
│   │   ├── tip_card_controller.js
│   │   ├── search_controller.js
│   │   ├── golf_ball_controller.js
│   │   └── course_map_controller.js
│   └── application.js      # Main JS entry point
├── assets/
│   ├── stylesheets/
│   │   └── application.css  # Tailwind + custom styles
│   └── images/
└── helpers/                # View helpers
    ├── ui_helper.rb
    └── golf_helper.rb
```

## Design System

### Color Palette

```css
/* app/assets/stylesheets/application.css */
@import "tailwindcss";

@layer base {
  :root {
    /* Primary Golf Green */
    --golf-green-50: #f0fdf4;
    --golf-green-500: #22c55e;
    --golf-green-600: #16a34a;
    --golf-green-700: #15803d;
    
    /* Dark Theme */
    --dark-bg: #0f0f0f;
    --dark-surface: #1a1a1a;
    --dark-card: #262626;
    --dark-border: #404040;
    --dark-text: #f5f5f5;
    --dark-text-muted: #a3a3a3;
    
    /* Accent Colors */
    --accent-blue: #3b82f6;
    --accent-amber: #f59e0b;
    --warning-red: #ef4444;
  }
}

/* Golf Ball Orb Component */
.golf-ball-orb {
  @apply relative w-40 h-40 mx-auto mb-8;
  background: radial-gradient(circle at 30% 30%, #ffffff, #e5e7eb);
  border-radius: 50%;
  box-shadow: 
    inset 0 0 20px rgba(0,0,0,0.1),
    0 10px 30px rgba(0,0,0,0.3);
}

.golf-ball-dimples {
  @apply absolute inset-0 opacity-20;
  background-image: 
    radial-gradient(circle at 20% 80%, #000 1px, transparent 1px),
    radial-gradient(circle at 80% 20%, #000 1px, transparent 1px),
    radial-gradient(circle at 40% 40%, #000 1px, transparent 1px);
  background-size: 15px 15px, 18px 18px, 12px 12px;
}
```

### Typography Scale

```erb
<!-- app/views/shared/_typography_system.html.erb -->
<% content_for :head do %>
  <style>
    /* Typography hierarchy inspired by Opal's clean text */
    .text-hero { @apply text-4xl font-bold tracking-tight text-white; }
    .text-title { @apply text-2xl font-semibold text-white; }
    .text-heading { @apply text-xl font-medium text-white; }
    .text-body { @apply text-base text-gray-300; }
    .text-caption { @apply text-sm text-gray-400; }
    .text-label { @apply text-xs font-medium text-gray-500 uppercase tracking-wide; }
  </style>
<% end %>
```

## Core Components

### 1. Golf Ball Progress Orb

```erb
<!-- app/views/components/ui/_golf_ball_orb.html.erb -->
<div class="golf-ball-orb" data-controller="golf-ball" data-golf-ball-progress-value="<%= progress %>">
  <div class="golf-ball-dimples"></div>
  
  <!-- Progress ring -->
  <svg class="absolute inset-0 transform -rotate-90" width="100%" height="100%">
    <circle
      cx="50%" cy="50%" r="75"
      stroke="currentColor"
      stroke-width="3"
      fill="none"
      class="text-gray-700"
    />
    <circle
      cx="50%" cy="50%" r="75"
      stroke="currentColor"
      stroke-width="3"
      fill="none"
      stroke-linecap="round"
      class="text-golf-green-500 transition-all duration-1000"
      stroke-dasharray="471"
      stroke-dashoffset="<%= 471 - (471 * progress / 100) %>"
      data-golf-ball-target="progressRing"
    />
  </svg>
  
  <!-- Center content -->
  <div class="absolute inset-0 flex items-center justify-center">
    <div class="text-center">
      <div class="text-hero" data-golf-ball-target="progressText"><%= progress %>%</div>
      <div class="text-caption">Progress</div>
    </div>
  </div>
</div>
```

### 2. Tip Card Component

```erb
<!-- app/views/components/tips/_tip_card.html.erb -->
<%= turbo_frame_tag "tip_#{tip.id}" do %>
  <div class="bg-dark-card rounded-2xl p-6 border border-dark-border group hover:border-golf-green-500/30 transition-all duration-300"
       data-controller="tip-card" 
       data-tip-card-tip-id-value="<%= tip.id %>">
    
    <!-- Header -->
    <div class="flex items-center justify-between mb-4">
      <div class="flex items-center space-x-3">
        <div class="w-10 h-10 bg-golf-green-500 rounded-full flex items-center justify-center">
          <span class="text-dark-bg font-semibold text-sm">
            <%= tip.user.name.first.upcase %>
          </span>
        </div>
        <div>
          <p class="text-white font-medium text-sm"><%= tip.user.name %></p>
          <p class="text-caption"><%= time_ago_in_words(tip.created_at) %> ago</p>
        </div>
      </div>
      
      <!-- Save button -->
      <button class="p-2 rounded-full hover:bg-dark-surface transition-colors"
              data-action="click->tip-card#toggleSave"
              data-tip-card-target="saveButton">
        <% if current_user.saved?(tip) %>
          <svg class="w-5 h-5 text-golf-green-500 fill-current" viewBox="0 0 20 20">
            <path d="M3 4a1 1 0 011-1h12a1 1 0 011 1v13.586l-6-6-6 6V4z"/>
          </svg>
        <% else %>
          <svg class="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 5a2 2 0 012-2h10a2 2 0 012 2v16l-7-3.5L5 21V5z"/>
          </svg>
        <% end %>
      </button>
    </div>
    
    <!-- Content -->
    <div class="mb-4">
      <h3 class="text-heading mb-2"><%= tip.title %></h3>
      <p class="text-body leading-relaxed"><%= tip.content %></p>
    </div>
    
    <!-- Tags -->
    <div class="flex flex-wrap gap-2 mb-4">
      <span class="px-3 py-1 bg-dark-surface rounded-full text-caption">
        <%= tip.category.name %>
      </span>
      <span class="px-3 py-1 bg-dark-surface rounded-full text-caption">
        <%= tip.phase.humanize %>
      </span>
      <% if tip.skill_level %>
        <span class="px-3 py-1 bg-dark-surface rounded-full text-caption">
          <%= tip.skill_level.humanize %>
        </span>
      <% end %>
    </div>
    
    <!-- Footer -->
    <div class="flex items-center justify-between pt-4 border-t border-dark-border">
      <div class="flex items-center space-x-4">
        <div class="flex items-center space-x-1">
          <svg class="w-4 h-4 text-golf-green-500" fill="currentColor" viewBox="0 0 20 20">
            <path d="M3 4a1 1 0 011-1h12a1 1 0 011 1v13.586l-6-6-6 6V4z"/>
          </svg>
          <span class="text-caption"><%= tip.save_count %></span>
        </div>
        
        <% if tip.ai_generated? %>
          <div class="flex items-center space-x-1">
            <div class="w-3 h-3 bg-accent-blue rounded-full"></div>
            <span class="text-caption">AI Generated</span>
          </div>
        <% end %>
      </div>
      
      <button class="text-golf-green-500 hover:text-golf-green-400 transition-colors"
              data-action="click->tip-card#share">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.367 2.684 3 3 0 00-5.367-2.684z"/>
        </svg>
      </button>
    </div>
  </div>
<% end %>
```

### 3. Bottom Navigation

```erb
<!-- app/views/shared/_bottom_navigation.html.erb -->
<div class="fixed bottom-0 left-0 right-0 bg-dark-surface border-t border-dark-border">
  <div class="flex items-center justify-around py-2 max-w-md mx-auto">
    
    <%= link_to tips_path, 
        class: "flex flex-col items-center py-2 px-4 #{nav_active?('tips') ? 'text-golf-green-500' : 'text-gray-400'}" do %>
      <svg class="w-6 h-6 mb-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"/>
      </svg>
      <span class="text-xs">Tips</span>
    <% end %>
    
    <%= link_to courses_path, 
        class: "flex flex-col items-center py-2 px-4 #{nav_active?('courses') ? 'text-golf-green-500' : 'text-gray-400'}" do %>
      <svg class="w-6 h-6 mb-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/>
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/>
      </svg>
      <span class="text-xs">Courses</span>
    <% end %>
    
    <!-- Center Action Button -->
    <button class="relative -top-4 w-14 h-14 bg-golf-green-500 rounded-full flex items-center justify-center shadow-lg"
            data-controller="fab-menu"
            data-action="click->fab-menu#toggle">
      <svg class="w-6 h-6 text-dark-bg" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
      </svg>
    </button>
    
    <%= link_to saved_tips_path, 
        class: "flex flex-col items-center py-2 px-4 #{nav_active?('saved') ? 'text-golf-green-500' : 'text-gray-400'}" do %>
      <svg class="w-6 h-6 mb-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 5a2 2 0 012-2h10a2 2 0 012 2v16l-7-3.5L5 21V5z"/>
      </svg>
      <span class="text-xs">Saved</span>
    <% end %>
    
    <%= link_to profile_path, 
        class: "flex flex-col items-center py-2 px-4 #{nav_active?('profile') ? 'text-golf-green-500' : 'text-gray-400'}" do %>
      <svg class="w-6 h-6 mb-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
      </svg>
      <span class="text-xs">Profile</span>
    <% end %>
  </div>
</div>
```

## Stimulus Controllers

### 1. Golf Ball Progress Controller

```javascript
// app/javascript/controllers/golf_ball_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["progressRing", "progressText"]
  static values = { progress: Number }

  connect() {
    this.animateProgress()
  }

  progressValueChanged() {
    this.animateProgress()
  }

  animateProgress() {
    const circumference = 471 // 2 * π * 75
    const offset = circumference - (circumference * this.progressValue) / 100
    
    // Animate the ring
    if (this.hasProgressRingTarget) {
      this.progressRingTarget.style.strokeDashoffset = offset
    }
    
    // Animate the text
    if (this.hasProgressTextTarget) {
      this.animateNumber(0, this.progressValue, 1000)
    }
  }

  animateNumber(start, end, duration) {
    const startTime = performance.now()
    
    const animate = (currentTime) => {
      const elapsed = currentTime - startTime
      const progress = Math.min(elapsed / duration, 1)
      
      const current = Math.floor(start + (end - start) * progress)
      this.progressTextTarget.textContent = `${current}%`
      
      if (progress < 1) {
        requestAnimationFrame(animate)
      }
    }
    
    requestAnimationFrame(animate)
  }
}
```

### 2. Tip Card Controller

```javascript
// app/javascript/controllers/tip_card_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["saveButton"]
  static values = { tipId: Number }

  async toggleSave(event) {
    event.preventDefault()
    
    try {
      const response = await fetch(`/tips/${this.tipIdValue}/save`, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
          'Accept': 'application/json'
        }
      })
      
      if (response.ok) {
        const data = await response.json()
        this.updateSaveButton(data.saved, data.save_count)
        this.showFeedback(data.saved ? 'Saved!' : 'Removed')
      }
    } catch (error) {
      console.error('Save failed:', error)
      this.showFeedback('Failed to save', 'error')
    }
  }

  updateSaveButton(saved, saveCount) {
    const icon = saved 
      ? '<svg class="w-5 h-5 text-golf-green-500 fill-current" viewBox="0 0 20 20"><path d="M3 4a1 1 0 011-1h12a1 1 0 011 1v13.586l-6-6-6 6V4z"/></svg>'
      : '<svg class="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 5a2 2 0 012-2h10a2 2 0 012 2v16l-7-3.5L5 21V5z"/></svg>'
    
    this.saveButtonTarget.innerHTML = icon
  }

  share(event) {
    event.preventDefault()
    
    if (navigator.share) {
      navigator.share({
        title: this.element.querySelector('.text-heading').textContent,
        text: this.element.querySelector('.text-body').textContent,
        url: window.location.href
      })
    } else {
      // Fallback to copy to clipboard
      this.copyToClipboard()
    }
  }

  copyToClipboard() {
    const text = `${this.element.querySelector('.text-heading').textContent}\n\n${this.element.querySelector('.text-body').textContent}`
    navigator.clipboard.writeText(text).then(() => {
      this.showFeedback('Copied to clipboard!')
    })
  }

  showFeedback(message, type = 'success') {
    // Create toast notification
    const toast = document.createElement('div')
    toast.className = `fixed top-4 right-4 px-4 py-2 rounded-lg text-white z-50 ${
      type === 'error' ? 'bg-warning-red' : 'bg-golf-green-500'
    }`
    toast.textContent = message
    
    document.body.appendChild(toast)
    
    setTimeout(() => {
      toast.remove()
    }, 3000)
  }
}
```

## Layout System

### Main Application Layout

```erb
<!-- app/views/layouts/application.html.erb -->
<!DOCTYPE html>
<html lang="en" class="dark">
  <head>
    <title>Personal Golf</title>
    <meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    
    <!-- PWA -->
    <%= render "shared/pwa_meta" %>
    
    <!-- Styles -->
    <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
    
    <!-- Scripts -->
    <%= javascript_importmap_tags %>
  </head>

  <body class="bg-dark-bg text-dark-text antialiased">
    <!-- Main Content -->
    <main class="min-h-screen pb-20">
      <!-- Top Bar -->
      <header class="sticky top-0 z-40 bg-dark-bg/80 backdrop-blur-lg border-b border-dark-border">
        <div class="px-4 py-3">
          <%= render "shared/top_bar" %>
        </div>
      </header>
      
      <!-- Page Content -->
      <div class="px-4 py-6">
        <% if notice %>
          <div class="mb-4 p-4 bg-golf-green-500/10 border border-golf-green-500/20 rounded-lg">
            <p class="text-golf-green-500"><%= notice %></p>
          </div>
        <% end %>
        
        <% if alert %>
          <div class="mb-4 p-4 bg-warning-red/10 border border-warning-red/20 rounded-lg">
            <p class="text-warning-red"><%= alert %></p>
          </div>
        <% end %>
        
        <%= yield %>
      </div>
    </main>
    
    <!-- Bottom Navigation -->
    <%= render "shared/bottom_navigation" if user_signed_in? %>
    
    <!-- Toast Container -->
    <div id="toast-container" class="fixed top-4 right-4 z-50 space-y-2"></div>
  </body>
</html>
```

## Responsive Design & Accessibility

### Mobile-First Breakpoints

```css
/* Custom responsive utilities in application.css */
@layer utilities {
  /* Golf-specific utilities */
  .course-card {
    @apply bg-dark-card rounded-2xl p-4 border border-dark-border;
    @apply hover:border-golf-green-500/30 transition-all duration-300;
    @apply md:p-6;
  }
  
  .tip-grid {
    @apply grid gap-4;
    @apply grid-cols-1;
    @apply md:grid-cols-2;
    @apply lg:grid-cols-3;
  }
  
  /* Opal-inspired animations */
  .fade-in {
    @apply opacity-0 translate-y-4;
    animation: fadeInUp 0.6s ease-out forwards;
  }
  
  .stagger-children > * {
    @apply fade-in;
  }
  
  .stagger-children > *:nth-child(1) { animation-delay: 0.1s; }
  .stagger-children > *:nth-child(2) { animation-delay: 0.2s; }
  .stagger-children > *:nth-child(3) { animation-delay: 0.3s; }
}

@keyframes fadeInUp {
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

/* Focus management */
.focus-ring {
  @apply focus:outline-none focus:ring-2 focus:ring-golf-green-500 focus:ring-offset-2 focus:ring-offset-dark-bg;
}

button, a, input, textarea, select {
  @apply focus-ring;
}
```

This UI architecture creates a clean, modern golf knowledge app inspired by Opal's design language while leveraging Rails 8's Hotwire features for real-time interactivity and smooth user experiences. The dark theme and green accents create a perfect golf-focused aesthetic that works beautifully on the course.