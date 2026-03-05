require "json"
require "net/http"
require "securerandom"
require "uri"

class ClawBridgeService
  ONBOARDING_QUESTIONS = [
    "Great to meet you. First, how would you describe your golf level right now: beginner, intermediate, or advanced?",
    "What is your current handicap (or your best estimate)?",
    "What are your top goals this season? You can list a few.",
    "How often are you practicing or playing each month?",
    "What shot or situation gives you the most trouble right now?"
  ].freeze

  ACTION_TYPES = %w[recommend_tip save_tip dismiss_tip complete_onboarding].freeze

  def initialize(user:, coach_session:, request_id: SecureRandom.uuid)
    @user = user
    @coach_session = coach_session
    @request_id = request_id
  end

  def respond_to(message:, context: {})
    sibling_result = call_sibling_service(message: message, context: context)
    return sibling_result if sibling_result.present?

    local_fallback_response(message: message, context: context)
  rescue StandardError => e
    Rails.logger.error("ClawBridgeService failed request_id=#{@request_id}: #{e.class} #{e.message}")
    local_fallback_response(message: message, context: context)
  end

  private

  def sibling_url
    ENV["CLAW_SIBLING_URL"].presence
  end

  def sibling_enabled?
    sibling_url.present?
  end

  def call_sibling_service(message:, context:)
    return nil unless sibling_enabled?

    uri = URI.join(sibling_url, "/v1/coach/respond")
    payload = {
      requestId: @request_id,
      transport: "app",
      userId: @user.id,
      coachSessionId: @coach_session.id,
      phase: @coach_session.phase,
      message: message,
      context: context
    }

    response = with_retries(max_attempts: 1) do
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 5
      http.read_timeout = 90

      request = Net::HTTP::Post.new(uri.request_uri, request_headers)
      request.body = payload.to_json
      http.request(request)
    end

    return nil unless response.is_a?(Net::HTTPSuccess)

    body = JSON.parse(response.body)
    normalize_response(body, source: "sibling_claw")
  rescue JSON::ParserError => e
    Rails.logger.warn("Invalid JSON from sibling claw request_id=#{@request_id}: #{e.message}")
    nil
  end

  def request_headers
    headers = { "Content-Type" => "application/json" }
    token = ENV["CLAW_SIBLING_TOKEN"].presence
    headers["Authorization"] = "Bearer #{token}" if token
    headers
  end

  def with_retries(max_attempts:)
    attempts = 0
    begin
      attempts += 1
      yield
    rescue Timeout::Error, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Net::OpenTimeout, Net::ReadTimeout => e
      raise if attempts >= max_attempts

      sleep(0.25 * attempts)
      Rails.logger.info("Retrying sibling claw request_id=#{@request_id}: #{e.class}")
      retry
    end
  end

  def local_fallback_response(message:, context:)
    if @coach_session.onboarding?
      onboarding_response(message)
    elsif explicit_tip_save_request?(message)
      {
        text: "Got it. I can save the most recent coach tip for you now.",
        actions: [ { type: "save_tip", payload: {} } ],
        profile_updates: {},
        source: "local_fallback"
      }
    elsif tip_request?(message)
      {
        text: "I put together a personalized tip for this moment. Save it if you want it in your collection.",
        actions: [ { type: "recommend_tip", payload: recommended_tip_payload(context) } ],
        profile_updates: {},
        source: "local_fallback"
      }
    else
      {
        text: context_aware_reply(context),
        actions: [],
        profile_updates: {},
        source: "local_fallback"
      }
    end
  end

  def onboarding_response(message)
    user_answers = @coach_session.coach_messages.user.count
    profile_updates = profile_updates_from_onboarding_answer(answer_index: user_answers, answer: message)

    if user_answers < ONBOARDING_QUESTIONS.length
      {
        text: ONBOARDING_QUESTIONS[user_answers],
        actions: [],
        profile_updates: profile_updates,
        source: "local_fallback"
      }
    else
      {
        text: "Perfect. I have enough to personalize your coaching. I will set up your profile and keep learning as you play.",
        actions: [ { type: "complete_onboarding", payload: {} } ],
        profile_updates: profile_updates,
        source: "local_fallback"
      }
    end
  end

  def profile_updates_from_onboarding_answer(answer_index:, answer:)
    case answer_index
    when 1
      { skill_level: normalize_skill_level(answer) }.compact
    when 2
      { handicap: extract_handicap(answer) }.compact
    when 3
      { goals: infer_goals(answer) }
    when 4
      { playing_frequency: answer.to_s.strip }
    when 5
      { biggest_challenge: answer.to_s.strip }
    else
      {}
    end
  end

  def normalize_skill_level(answer)
    text = answer.to_s.downcase
    return "advanced" if text.include?("adv")
    return "intermediate" if text.include?("inter") || text.include?("mid")
    return "beginner" if text.include?("beg") || text.include?("new")

    nil
  end

  def extract_handicap(answer)
    match = answer.to_s.match(/-?\d+(\.\d+)?/)
    return nil unless match

    value = match[0].to_f.round
    return nil if value.negative? || value > 54

    value
  end

  def infer_goals(answer)
    text = answer.to_s.downcase
    goals = []
    goals << "lower_scores" if text.match?(/score|lower|break|under|better rounds?/)
    goals << "consistency" if text.match?(/consisten|repeat|steady/)
    goals << "technique" if text.match?(/swing|technique|mechanic|ball.strik/)
    goals << "mental_game" if text.match?(/mental|confidence|focus|pressure/)
    goals << "fitness" if text.match?(/fitness|strength|mobility|flexibility/)
    goals << "enjoyment" if goals.empty?
    goals.uniq
  end

  def explicit_tip_save_request?(message)
    text = message.to_s.downcase
    return false unless text.include?("tip")

    text.match?(/\b(save|bookmark|keep)\b/)
  end

  def tip_request?(message)
    message.to_s.downcase.match?(/\b(tip|advice|recommend|what should i do|help me)\b/)
  end

  def recommended_tip_payload(context)
    category_slug = if context.is_a?(Hash) && context["hole_number"].present?
      "course-tip"
    else
      "basics"
    end

    {
      title: "Pick one target and commit",
      content: "Before every shot, choose a precise target and rehearse one smooth feel. Commit to that feel through impact to reduce indecision and dispersion.",
      category_slug: category_slug,
      phase: context["phase"] || "during_round"
    }
  end

  def context_aware_reply(context)
    if context.is_a?(Hash) && context["hole_number"].present?
      "On this hole, play to your safest miss and prioritize center-green outcomes unless you have a clear scoring opportunity."
    else
      "I can help with prep, in-round decisions, or a post-round debrief. Ask for a tip and I can add it directly to your collection."
    end
  end

  def normalize_response(body, source:)
    {
      text: body["text"].to_s,
      actions: normalize_actions(body["actions"]),
      profile_updates: body["profileUpdates"].is_a?(Hash) ? body["profileUpdates"] : {},
      source: source
    }
  end

  def normalize_actions(raw_actions)
    Array(raw_actions).filter_map do |action|
      next unless action.is_a?(Hash)

      type = action["type"].to_s
      next unless ACTION_TYPES.include?(type)

      {
        type: type,
        payload: action["payload"].is_a?(Hash) ? action["payload"] : {}
      }
    end
  end
end
