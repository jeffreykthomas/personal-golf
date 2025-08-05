# Personal Golf

A Progressive Web App (PWA) built with **Ruby on Rails 8** that helps golfers organize, discover, and share knowledge to play their best golf. The app serves as a comprehensive knowledge management system for golf tips, routines, and course-specific insights.

## 🏌️ Features

- **Personal Knowledge Collection**: Save and organize golf tips across all categories
- **AI-Powered Content**: Generate personalized tips using Google Gemini API
- **Community-Driven**: Share knowledge and discover tips from other golfers
- **Course-Specific Insights**: Local knowledge and photos for golf courses
- **Progressive Web App**: Works offline, installable on mobile devices
- **Real-time Updates**: Live sharing and notifications via Solid Cable

## 🚀 Rails 8 "No PaaS Required" Architecture

This app leverages Rails 8's simplified deployment stack:

- **Solid Queue**: Database-backed background jobs (no Redis needed)
- **Solid Cache**: Disk-based caching for larger, persistent cache
- **Solid Cable**: Database-backed WebSockets for real-time features
- **SQLite**: Production-ready database with Rails 8 optimizations
- **Kamal 2**: Deploy anywhere with simple configuration

## 🛠 Tech Stack

- **Framework**: Ruby on Rails 8.0.2
- **Language**: Ruby 3.3.7
- **Frontend**: Hotwire (Turbo + Stimulus)
- **Styling**: Tailwind CSS
- **Database**: SQLite3 (production-ready)
- **Deployment**: Kamal 2 + Docker
- **AI**: Google Gemini API
- **PWA**: Service Workers, Web App Manifest

## 📚 Documentation

Comprehensive documentation is available in the `/docs` folder:

- [App Overview](docs/app-overview.md) - Vision and core concepts
- [Technical Architecture](docs/technical-architecture.md) - System design and Rails 8 features
- [API Design](docs/api-design.md) - RESTful endpoints and real-time features
- [Data Flow](docs/data-flow.md) - Database design and background processing
- [User Experience Guide](docs/user-experience-guide.md) - UX principles and onboarding
- [UI Architecture](docs/ui-architecture.md) - Frontend implementation details
- [PWA Features](docs/pwa-features.md) - Offline capabilities and installation
- [Quick Start Guide](docs/quick-start-guide.md) - Developer setup and core features
- [Deployment Guide](docs/deployment-guide.md) - Production deployment with Kamal

## 🚀 Quick Start

### Prerequisites

- Ruby 3.3.7+ (Rails 8 requirement)
- SQLite3
- Node.js (for Tailwind CSS compilation)

### Setup

```bash
# Clone the repository
git clone https://github.com/your-username/personal-golf.git
cd personal-golf

# Install dependencies
bundle install

# Setup database
rails db:create db:migrate db:seed

# Install and build Tailwind CSS
rails assets:precompile

# Start the development server
bin/dev
```

The app will be available at `http://localhost:3000`

### Development Commands

```bash
# Start all services (Rails + Tailwind watcher)
bin/dev

# Run Rails server only
rails server

# Run background jobs
bin/jobs

# Run tests
rails test

# Run linter
bundle exec rubocop

# Run security scanner
bundle exec brakeman
```

## 🐳 Deployment

Deploy to any VPS using Kamal 2:

```bash
# Setup Kamal configuration
kamal setup

# Deploy application
kamal deploy

# Check deployment status
kamal app logs
```

See the [Deployment Guide](docs/deployment-guide.md) for detailed instructions.

## 🎯 Core Models

```ruby
# User authentication (Rails 8 built-in)
class User < ApplicationRecord
  has_secure_password
  has_many :tips, :saves, :sessions
end

# Golf tips and knowledge
class Tip < ApplicationRecord
  belongs_to :user, :category
  has_many :saves, counter_cache: true
  
  # Real-time broadcasts
  broadcasts_to :category
  
  # Background processing
  after_create_commit :process_tip_async
end

# User's saved collection
class Save < ApplicationRecord
  belongs_to :user, :tip
  validates :user_id, uniqueness: { scope: :tip_id }
end
```

## 🧪 Testing

```bash
# Run all tests
rails test

# Run specific test files
rails test test/models/tip_test.rb
rails test test/controllers/tips_controller_test.rb

# Run system tests
rails test:system
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Follow Rails conventions and best practices
- Write tests for new features
- Run `bundle exec rubocop` before committing
- Update documentation for significant changes

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🎯 Project Goals

This is an open-source learning project exploring:

- Rails 8's "No PaaS Required" philosophy
- Modern PWA development with Rails
- AI integration for content generation
- Community-driven knowledge sharing
- Simplified deployment strategies

The goal is to create a useful tool for golfers while learning the latest Rails 8 features and demonstrating how to build modern web applications without complex infrastructure dependencies.

---

Built with ❤️ and Rails 8