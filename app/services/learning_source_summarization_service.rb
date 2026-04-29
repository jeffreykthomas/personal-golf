require "digest"
require "net/http"
require "uri"

class LearningSourceSummarizationService
  CONTENT_LIMIT = 8_000

  def initialize(source:)
    @source = source
  end

  def call
    extracted = extract_content
    content = extracted[:content].to_s

    if content.blank? && @source.upload?
      @source.update!(
        extraction_status: :needs_review,
        summary_markdown: fallback_summary_markdown(extracted[:title]),
        extracted_content: nil,
        content_hash: Digest::SHA256.hexdigest(@source.display_title.to_s)
      )
      return @source
    end

    payload = NanoclawLearningBridgeService.summarize_source(
      source: @source,
      extracted_content: content,
      extracted_title: extracted[:title]
    )

    @source.update!(
      title: payload&.dig("title").to_s.strip.presence || extracted[:title].presence || @source.title,
      summary_markdown: payload&.dig("summary_markdown").to_s.strip.presence || fallback_summary_markdown(extracted[:title], content: content),
      extracted_content: content,
      content_hash: Digest::SHA256.hexdigest(content),
      extraction_status: :summarized,
      metadata: (@source.metadata || {}).except("last_error").merge(
        "last_summarized_at" => Time.current.iso8601,
        "key_points" => Array(payload&.dig("key_points")).first(5),
        "last_summarized_by" => "nanoclaw"
      )
    )

    @source
  rescue StandardError => e
    Rails.logger.error("Learning source summarization failed source=#{@source.id}: #{e.class} #{e.message}")
    @source.update(extraction_status: :failed, metadata: (@source.metadata || {}).merge("last_error" => e.message))
    @source
  end

  private

  def extract_content
    return extract_upload_content if @source.upload?
    return extract_remote_content if @source.url.present?

    { title: @source.title, content: nil }
  end

  def extract_upload_content
    return { title: @source.title, content: nil } unless @source.uploaded_file.attached?

    blob = @source.uploaded_file.blob
    title = @source.title.presence || blob.filename.base
    content_type = blob.content_type.to_s

    if content_type.start_with?("text/") || content_type.include?("json") || content_type.include?("markdown")
      content = @source.uploaded_file.download.force_encoding("UTF-8").scrub.first(CONTENT_LIMIT)
      { title: title, content: content }
    else
      {
        title: title,
        content: "Uploaded file named #{blob.filename}. Automatic text extraction is not configured for content type #{content_type.presence || 'unknown'} yet."
      }
    end
  end

  def extract_remote_content
    uri = URI.parse(@source.url)
    body, content_type = fetch_uri(uri)
    return { title: @source.title, content: nil } if body.blank?

    if content_type.to_s.include?("html")
      title = body[/\<title\>(.*?)\<\/title\>/im, 1].to_s.squish.presence || @source.title
      text = ActionController::Base.helpers.strip_tags(body).squish.first(CONTENT_LIMIT)
      { title: title, content: text }
    elsif content_type.to_s.start_with?("text/") || content_type.to_s.include?("json") || content_type.to_s.include?("xml")
      { title: @source.title, content: body.to_s.force_encoding("UTF-8").scrub.first(CONTENT_LIMIT) }
    else
      {
        title: @source.title,
        content: "Remote source #{@source.url} was fetched, but automatic extraction is not configured for content type #{content_type.presence || 'unknown'} yet."
      }
    end
  rescue URI::InvalidURIError
    { title: @source.title, content: nil }
  end

  def fetch_uri(uri, redirects_remaining = 2)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 5
    http.read_timeout = 10

    request = Net::HTTP::Get.new(uri.request_uri.presence || "/")
    request["User-Agent"] = "PersonalLifeLearning/1.0"

    response = http.request(request)

    case response
    when Net::HTTPSuccess
      [response.body, response["Content-Type"]]
    when Net::HTTPRedirection
      return [nil, nil] if redirects_remaining <= 0

      next_uri = URI.join(uri, response["location"].to_s)
      fetch_uri(next_uri, redirects_remaining - 1)
    else
      [nil, nil]
    end
  end

  def fallback_summary_markdown(extracted_title, content: nil)
    [
      "## Source Overview",
      "#{extracted_title.presence || @source.title} is attached to this learning topic.",
      "",
      "## Notes",
      content.to_s.first(300).presence || "This source needs a manual review or a future extraction pass for deeper summarization."
    ].join("\n")
  end
end
