# config/initializers/gemini.rb

# Configure Google Cloud AI Platform
# The official gem uses service account credentials or Application Default Credentials
# No global configuration needed - handled per-client in GeminiService

# Validate required credentials are present (skip during Docker build)
Rails.application.config.after_initialize do
  # Skip validation during Docker build
  next if ENV['SECRET_KEY_BASE_DUMMY']
  
  project_id = ENV['GOOGLE_CLOUD_PROJECT'] || ENV['google_cloud_project_id'] || Rails.application.credentials.google_cloud_project_id
  unless project_id
    Rails.logger.warn "Missing google_cloud_project_id in credentials or environment - AI features may not work"
  end
  
  # Either service account key OR Application Default Credentials OR Workload Identity should be available
  has_service_account = Rails.application.credentials.google_service_account_key.present?
  has_workload_identity = ENV['GOOGLE_WORKLOAD_IDENTITY_AUDIENCE'].present? && ENV['GOOGLE_SERVICE_ACCOUNT_EMAIL'].present?
  has_adc = ENV['GOOGLE_APPLICATION_CREDENTIALS'].present? || 
            (ENV['GOOGLE_CLOUD_PROJECT'].present? && system('gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null'))
  
  unless has_service_account || has_adc || has_workload_identity
    Rails.logger.warn "No Google Cloud credentials found - AI features may not work. Set up either service account key, Application Default Credentials, or Workload Identity Federation"
  end
end