# Skip during Docker build
unless ENV['SECRET_KEY_BASE_DUMMY']
  Rails.application.config.middleware.use OmniAuth::Builder do
    provider :google_oauth2, 
             ENV['GOOGLE_CLIENT_ID'] || Rails.application.credentials.dig(:google, :client_id),
             ENV['GOOGLE_CLIENT_SECRET'] || Rails.application.credentials.dig(:google, :client_secret),
             {
               scope: 'email,profile',
               prompt: 'select_account',
               image_aspect_ratio: 'square',
               image_size: 50,
               access_type: 'offline',
               approval_prompt: 'force'
             }
  end
end

# Handle CSRF protection for OAuth
OmniAuth.config.allowed_request_methods = [:post, :get]
OmniAuth.config.silence_get_warning = true