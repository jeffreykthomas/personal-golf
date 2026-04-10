require "uri"

class LearningSource < ApplicationRecord
  belongs_to :learning_node
  has_one_attached :uploaded_file

  attribute :metadata, :json, default: {}

  enum :source_type, { agent_found: 0, user_url: 1, upload: 2 }
  enum :extraction_status, { discovered: 0, fetching: 1, summarized: 2, needs_review: 3, failed: 4 }

  validates :title, presence: true
  validates :url, presence: true, unless: :upload?
  validate :upload_requires_attachment
  validate :url_must_be_http, unless: :upload?

  after_destroy_commit :purge_uploaded_file_attachment
  after_commit :broadcast_learning_workspace_refresh

  def display_title
    title.presence || uploaded_file.filename.to_s.presence || url
  end

  def citation_label
    [author_name, publication_name, published_on].compact.join(" • ")
  end

  private

  def purge_uploaded_file_attachment
    uploaded_file.purge_later if uploaded_file.attached?
  end

  def upload_requires_attachment
    return unless upload?
    return if uploaded_file.attached?

    errors.add(:uploaded_file, "must be attached for upload sources")
  end

  def url_must_be_http
    return if url.blank?

    uri = URI.parse(url)
    return if uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)

    errors.add(:url, "must be a valid HTTP or HTTPS URL")
  rescue URI::InvalidURIError
    errors.add(:url, "must be a valid HTTP or HTTPS URL")
  end

  def broadcast_learning_workspace_refresh
    return unless learning_node&.user.present?

    broadcast_refresh_later_to(learning_node.user.learning_workspace_stream_name)
  end
end
