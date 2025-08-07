# app/services/gemini_service.rb
require 'google/cloud/ai_platform'
require 'net/http'
require 'uri'

class GeminiService
  def self.generate_tip(user_profile:, category:, context: {})
    prompt = build_golf_tip_prompt(user_profile, category, context)
    
    begin
      client = vertex_ai_client
      
      # Build the request for Vertex AI
      request = {
        instances: [{
          prompt: prompt
        }],
        parameters: {
          temperature: 0.7,
          max_output_tokens: 500,
          top_p: 0.8,
          top_k: 40
        }
      }
      
      # Make prediction request
      response = client.predict(
        endpoint: model_endpoint,
        instances: request[:instances],
        parameters: request[:parameters]
      )
      
      if response && response.predictions&.any?
        parse_vertex_ai_response(response)
      else
        Rails.logger.error "Vertex AI: No predictions in response"
        nil
      end
      
    rescue => e
      Rails.logger.error "Vertex AI generation failed: #{e.class} - #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.first(5).join('\n')}"
      nil
    end
  end
  
  private
  
  def self.build_golf_tip_prompt(user_profile, category, context)
    recent_saves_context = if context[:recent_saves]&.any?
      "They've recently saved tips about: #{context[:recent_saves].join(', ')}"
    else
      "This is one of their first tips in this category."
    end
    
    <<~PROMPT
      You are a professional golf instructor creating a personalized tip.
      
      User Profile:
      - Skill Level: #{user_profile[:skill_level] || 'beginner'}
      - Handicap: #{user_profile[:handicap] || 'Not specified'}
      - Experience: #{user_profile[:experience_level] || 'new_user'}
      - Goals: #{user_profile[:goals]&.join(', ') || 'General improvement'}
      - Favorite Categories: #{user_profile[:favorite_categories]&.join(', ') || 'None yet'}
      
      Context:
      - Category: #{category}
      - Time: #{context[:time_of_day] || 'any time'}
      - #{recent_saves_context}
      
      Create a golf tip that is:
      1. Specific and actionable
      2. Appropriate for their skill level
      3. Different from their recent saves
      4. Practical to implement
      
      Format your response as valid JSON:
      {
        "title": "Engaging title under 80 characters",
        "content": "Detailed tip with specific instructions under 800 characters",
        "phase": "pre_round" | "during_round" | "post_round",
        "youtube_url": "Optional YouTube URL for a relevant instructional video (only include if highly relevant)"
      }
      
      Make the tip personal, practical, and immediately useful.
    PROMPT
  end
  
  def self.vertex_ai_client
    @client ||= begin
      if ENV['GOOGLE_WORKLOAD_IDENTITY_AUDIENCE']
        # Use Workload Identity Federation
        require 'googleauth'

        scope = 'https://www.googleapis.com/auth/cloud-platform'

        # Get Fly.io token
        fly_token = fetch_fly_token

        # Exchange for Google token
        authorizer = Google::Auth::ExternalAccount::Authorizer.new(
          audience: ENV['GOOGLE_WORKLOAD_IDENTITY_AUDIENCE'],
          subject_token_type: 'urn:ietf:params:oauth:token-type:jwt',
          token_url: 'https://sts.googleapis.com/v1/token',
          credential_source: {
            format: {
              type: 'json',
              subject_token_field_name: 'token'
            },
            data: { token: fly_token }
          },
          service_account_impersonation_url: "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/#{ENV['GOOGLE_SERVICE_ACCOUNT_EMAIL']}:generateAccessToken",
          scopes: [scope]
        )

        Google::Cloud::AIPlatform.prediction_service do |config|
          config.credentials = authorizer
        end
      elsif Rails.application.credentials.google_service_account_key
        # Fall back to service account key
        Google::Cloud::AIPlatform.prediction_service do |config|
          config.credentials = service_account_credentials
        end
      else
        # Use Application Default Credentials
        Google::Cloud::AIPlatform.prediction_service
      end
    end
  end
  
  def self.model_endpoint
    # Vertex AI endpoint for Gemini Pro
    project_id = ENV['GOOGLE_CLOUD_PROJECT'] || Rails.application.credentials.google_cloud_project_id
    region = 'us-central1' # or your preferred region
    model_id = 'gemini-pro'
    
    "projects/#{project_id}/locations/#{region}/publishers/google/models/#{model_id}"
  end
  
  def self.fetch_fly_token
    # Fly.io provides tokens at this endpoint
    uri = URI('http://[::1]:3000/.fly/api/tokens/oidc')
    response = Net::HTTP.get_response(uri)
    response.body if response.is_a?(Net::HTTPSuccess)
  rescue => e
    Rails.logger.error "Failed to fetch Fly.io token: #{e.message}"
    nil
  end
  
  def self.service_account_credentials
    # Use service account key file or Application Default Credentials
    if Rails.application.credentials.google_service_account_key
      JSON.parse(Rails.application.credentials.google_service_account_key)
    else
      # Will use Application Default Credentials (ADC)
      nil
    end
  end
  
  def self.parse_vertex_ai_response(response)
    # Vertex AI response structure is different
    prediction = response.predictions&.first
    return nil unless prediction
    
    text = prediction['content'] || prediction['generated_text'] || prediction.to_s
    return nil unless text.present?
    
    # Try to extract JSON from response
    json_match = text.match(/\{.*?\}/m)
    return nil unless json_match
    
    parsed = JSON.parse(json_match[0])
    
    # Validate required fields
    return nil unless parsed['title'] && parsed['content']
    
    # Ensure phase is valid
    valid_phases = %w[pre_round during_round post_round]
    parsed['phase'] = 'during_round' unless valid_phases.include?(parsed['phase'])
    
    # Truncate if too long
    parsed['title'] = parsed['title'][0..99] if parsed['title'].length > 100
    parsed['content'] = parsed['content'][0..999] if parsed['content'].length > 1000
    
    # Validate YouTube URL if present
    if parsed['youtube_url'].present?
      youtube_pattern = /\A(https?:\/\/)?(www\.)?(youtube\.com\/watch\?v=|youtu\.be\/)[a-zA-Z0-9_-]{11}(\?.*)?\z/
      parsed['youtube_url'] = nil unless parsed['youtube_url'].match?(youtube_pattern)
    end
    
    parsed.with_indifferent_access
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse Vertex AI response JSON: #{e.message}"
    Rails.logger.error "Response text: #{text}"
    nil
  end
end