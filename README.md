# Personal Golf

A Progressive Web App (PWA) built with **Ruby on Rails 8** that helps golfers organize, discover, and share knowledge to play their best golf. The app serves as a comprehensive knowledge management system for golf tips, routines, and course-specific insights.

## 🏌️ Features

- **Personal Knowledge Collection**: Save and organize golf tips across all categories
- **AI-Powered Content**: Generate personalized tips using Google Gemini API
- **YouTube Integration**: Tips can include relevant instructional videos with thumbnails
- **Community-Driven**: Share knowledge and discover tips from other golfers
- **Course-Specific Insights**: Local knowledge and photos for golf courses
- **Progressive Web App**: Works offline, installable on mobile devices
- **Real-time Updates**: Live sharing and notifications via Solid Cable

## Tip Types & Examples

- **Technical**: "Shallow the downswing by feeling the trail elbow lead the hips. Make 3 slow pump rehearsals, then swing at 80% to start the ball right-edge and draw back."
- **Mental game**: "Use box-breathing (4-4-4-4) while picking a tiny intermediate target. After exhale, commit to one swing thought: tempo only."
- **Preparation**: "Green-speed ladder drill: putt 10, 20, 30 feet stopping pin-high. Note the backstroke length that reliably reaches each distance and use it in the round."
- **Course management**: "When approach > 7-iron or into the wind, aim for the fat side. Take one extra club and swing 80% to avoid the short-side miss—bogeys drop fast with this rule."
- **Specific course**: "Example – Hole 4, 175y par 3, water front-left: tee to right-center; long is safe. On afternoon headwinds, take one more club and flight it down."

### Available Tip Tags

These tags can be attached to tips for filtering and discovery:

- **Clubs**: driver, fairway_woods, long_irons, short_irons, wedges, putter
- **Shots**: full_shots, punch_shots, hook_shots, slice_shots, fairway_bunker, pitches, chips, flop_shots, greenside_bunker, long_putts, short_putts
- **Mental Game**: pre-shot_routine, visualization, breathing, focus, confidence, positive_self-talk, commitment, acceptance, emotional_control, routine_under_pressure, post-shot_processing

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

## Getting Started

- Visit the hosted app at `https://your-domain.example`.
- Create a free account and log in to start saving and discovering tips.
- AI-generated tips are an optional paid add-on; no local setup or keys required. Pricing and activation flow will be provided in-app.

## For Developers & Contributors

- To run locally or contribute, see the [Quick Start Guide](docs/quick-start-guide.md) and [Deployment Guide](docs/deployment-guide.md).

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
