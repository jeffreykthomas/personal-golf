ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"

module TestDataHelpers
  DEFAULT_PASSWORD = "password123".freeze

  def build_user(attributes = {})
    sequence = SecureRandom.hex(4)

    User.new({
      email_address: "user-#{sequence}@example.com",
      password: DEFAULT_PASSWORD,
      password_confirmation: DEFAULT_PASSWORD,
      name: "Test User",
      onboarding_completed: true
    }.merge(attributes))
  end

  def create_user(attributes = {})
    user = build_user(attributes)
    user.save!
    user
  end

  def create_category(attributes = {})
    sequence = SecureRandom.hex(4)
    Category.create!({
      name: "Category #{sequence}"
    }.merge(attributes))
  end

  def create_golf_tip(user:, category:, attributes: {})
    GolfTip.create!({
      title: "Helpful Tip #{SecureRandom.hex(3)}",
      content: "A useful coaching note that is long enough to pass validation.",
      user: user,
      category: category,
      published: true,
      skill_level: :beginner,
      phase: :during_round
    }.merge(attributes))
  end

  def create_learning_node(user:, parent: nil, **attributes)
    LearningNode.create!({
      user: user,
      parent: parent,
      title: "Topic #{SecureRandom.hex(3)}",
      summary: "A learning topic.",
      body_markdown: "## Current Understanding\n\nA starting note.",
      status: :ready
    }.merge(attributes))
  end

  def create_learning_source(node:, **attributes)
    LearningSource.create!({
      learning_node: node,
      title: "Source #{SecureRandom.hex(3)}",
      url: "https://example.com/#{SecureRandom.hex(2)}",
      source_type: :user_url,
      extraction_status: :summarized,
      summary_markdown: "## Source Overview\n\nA summarized source."
    }.merge(attributes))
  end
end

class ActiveSupport::TestCase
  include TestDataHelpers
  include ActiveJob::TestHelper

  self.use_transactional_tests = true
end

class ActionDispatch::IntegrationTest
  include TestDataHelpers

  private

  def sign_in_as(user, password: TestDataHelpers::DEFAULT_PASSWORD)
    post session_path, params: {
      email_address: user.email_address,
      password: password
    }

    follow_redirect! if response.redirect?
  end
end
