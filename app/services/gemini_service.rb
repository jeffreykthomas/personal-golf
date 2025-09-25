# app/services/gemini_service.rb
require 'net/http'
require 'json'
require 'base64'

class GeminiService
  def self.generate_tip(user_profile:, category:, context: {})
    prompt = build_golf_tip_prompt(user_profile, category, context)

    begin
      text = call_google_genai(prompt)
      parse_genai_text(text)
    rescue => e
      Rails.logger.error "Gemini generation failed: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      nil
    end
  end

  def self.stylize_course_image(image_bytes, seed: nil, input_mime_type: 'image/png')
    # Uses Google Generative AI to restyle an uploaded hole layout image to match app aesthetics.
    # image_bytes: raw bytes from the uploaded file
    api_key = ENV['GOOGLE_API_KEY']
    raise 'Missing GOOGLE_API_KEY' if api_key.blank?

    model = 'gemini-2.5-flash-image-preview'
    uri = URI("https://generativelanguage.googleapis.com/v1beta/models/#{model}:generateContent?key=#{api_key}")

    headers = { 'Content-Type' => 'application/json' }
    prompt = <<~P
      Restyle this golf hole layout image to match a dark, minimalist UI.
      Requirements:
      - High-contrast lines and labels
      - Dark background, subtle greens
      - Clean typography for hole number, par, and yardage if present
      - Keep geometry, fairways, greens, hazards faithful to the original
      Return PNG image bytes only.
    P

    # Encode source image as base64 for inlineData
    encoded = Base64.strict_encode64(image_bytes)

    # Include seed instruction directly in the prompt to avoid unsupported systemInstruction
    prompt = "Use consistent visual style with seed #{seed}.\n" + prompt if seed

    body = {
      contents: [
        {
          role: 'user',
          parts: [
            { text: prompt },
            {
              inlineData: {
                mimeType: input_mime_type,
                data: encoded
              }
            }
          ]
        }
      ],
      generationConfig: {
        temperature: 0.4
      }
    }

    # No systemInstruction to maximize compatibility across image models

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 120
    request = Net::HTTP::Post.new(uri.request_uri, headers)
    request.body = body.to_json

    attempts = 0
    begin
      attempts += 1
      response = http.request(request)
      unless response.is_a?(Net::HTTPSuccess)
        raise "GenAI image stylization error: #{response.code} #{response.body}"
      end
    rescue => e
      retryable = e.is_a?(Net::ReadTimeout) ||
                  e.message.include?(' 500 ') ||
                  e.message.include?(' 429 ') ||
                  e.message.include?(' 503 ') ||
                  e.message.include?('INTERNAL')
      if attempts < 3 && retryable
        sleep(0.5 * (2 ** (attempts - 1)))
        retry
      end
      raise
    end

    raw_body = response.body
    data = JSON.parse(raw_body)
    parts = data.dig('candidates', 0, 'content', 'parts') || []
    # Prefer inlineData (camelCase) if the model returned a binary part
    blob_b64 = parts.find { |p| p['inlineData'] }&.dig('inlineData', 'data')
    # Support snake_case inline_data as well
    blob_b64 ||= parts.find { |p| p['inline_data'] }&.dig('inline_data', 'data')
    if blob_b64.present?
      return Base64.decode64(blob_b64)
    end

    # Fallback: some responses may return base64 image in text
    text_part = parts.find { |p| p['text'].is_a?(String) }&.dig('text')
    if text_part.present?
      # Try to extract data URL first
      if (m = text_part.match(/data:image\/(png|jpeg);base64,([A-Za-z0-9+\/=\n\r]+)/i))
        return Base64.decode64(m[2])
      end
      # Or a raw base64 blob (heuristic: long, base64-like)
      compact = text_part.gsub(/\s+/, '')
      if compact.length > 500 && compact.match?(/\A[A-Za-z0-9+\/]+=*\z/)
        begin
          return Base64.decode64(compact)
        rescue
          # ignore and fall through
        end
      end
    end

    Rails.logger.warn "Gemini stylize returned no image data. First 400 bytes of raw response: #{raw_body.to_s[0,400]}"
    nil
  rescue => e
    Rails.logger.error "Gemini stylize_course_image failed: #{e.class} - #{e.message}"
    raise
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

  def self.call_google_genai(prompt)
    api_key = ENV['GOOGLE_API_KEY']
    raise 'Missing GOOGLE_API_KEY' if api_key.blank?

    # Image-to-image capable model that returns inlineData
    model = 'gemini-2.5-flash-image-preview'
    uri = URI("https://generativelanguage.googleapis.com/v1beta/models/#{model}:generateContent?key=#{api_key}")

    headers = { 'Content-Type' => 'application/json' }
    body = {
      contents: [
        {
          parts: [
            { text: prompt }
          ]
        }
      ],
      generationConfig: {
        temperature: 0.7,
        maxOutputTokens: 500,
        topP: 0.8,
        topK: 40
      }
    }

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(uri.request_uri, headers)
    request.body = body.to_json

    response = http.request(request)
    unless response.is_a?(Net::HTTPSuccess)
      raise "GenAI API error: #{response.code} #{response.body}" 
    end

    data = JSON.parse(response.body)
    # extract text from candidates
    text = data.dig('candidates', 0, 'content', 'parts', 0, 'text')
    text.to_s
  end

  def self.parse_genai_text(text)
    return nil unless text.present?

    # Try to extract JSON from the model output
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
    Rails.logger.error "Failed to parse Gemini response JSON: #{e.message}"
    Rails.logger.error "Response text: #{text}"
    nil
  end
end