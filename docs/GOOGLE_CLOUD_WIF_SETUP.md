# Google Cloud Workload Identity Federation with Fly.io

This guide shows how to set up secure, keyless authentication between Fly.io and Google Cloud.

## Why Workload Identity Federation?

- **No service account keys** to manage or rotate
- **No credentials** stored in your app
- **Automatic authentication** based on Fly.io's identity
- **Granular access control** by environment

## Prerequisites

- Google Cloud project with billing enabled
- Fly.io app deployed
- `gcloud` CLI installed

## Step 1: Enable Required APIs

```bash
gcloud services enable iamcredentials.googleapis.com \
  cloudresourcemanager.googleapis.com \
  sts.googleapis.com \
  aiplatform.googleapis.com
```

## Step 2: Create Workload Identity Pool

```bash
# Set your project ID
export PROJECT_ID="your-google-cloud-project-id"
export POOL_ID="fly-io-pool"
export PROVIDER_ID="fly-io-provider"

# Create the pool
gcloud iam workload-identity-pools create $POOL_ID \
  --location="global" \
  --display-name="Fly.io Applications" \
  --description="Identity pool for Fly.io apps"
```

## Step 3: Create Workload Identity Provider

```bash
# Get your Fly.io app details
export FLY_APP_NAME="golf-tip-app"

# Create the provider for Fly.io (OIDC)
gcloud iam workload-identity-pools providers create-oidc $PROVIDER_ID \
  --location="global" \
  --workload-identity-pool=$POOL_ID \
  --issuer-uri="https://oidc.fly.io" \
  --attribute-mapping="google.subject=assertion.sub,attribute.app_name=assertion.app_name" \
  --attribute-condition="assertion.app_name == '$FLY_APP_NAME'"
```

## Step 4: Create Service Account

```bash
export SA_NAME="golf-tip-ai"
export SA_EMAIL="$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com"

# Create service account
gcloud iam service-accounts create $SA_NAME \
  --display-name="Golf Tip AI Service Account" \
  --description="Used by Fly.io app for AI generation"

# Grant necessary permissions
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/aiplatform.user"
```

## Step 5: Allow Fly.io to Impersonate Service Account

```bash
# Get the workload identity pool principal
export WORKLOAD_IDENTITY_PRINCIPAL="principal://iam.googleapis.com/projects/$(gcloud config get-value project)/locations/global/workloadIdentityPools/$POOL_ID/subject/fly:app:$FLY_APP_NAME"

# Grant impersonation permission
gcloud iam service-accounts add-iam-policy-binding $SA_EMAIL \
  --member="$WORKLOAD_IDENTITY_PRINCIPAL" \
  --role="roles/iam.workloadIdentityUser"
```

## Step 6: Configure Fly.io App

Set environment variables in Fly.io:

```bash
# Set the service account email
fly secrets set GOOGLE_SERVICE_ACCOUNT_EMAIL=$SA_EMAIL

# Set the project ID
fly secrets set GOOGLE_CLOUD_PROJECT=$PROJECT_ID

# Set the workload identity configuration
fly secrets set GOOGLE_WORKLOAD_IDENTITY_AUDIENCE="//iam.googleapis.com/projects/$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')/locations/global/workloadIdentityPools/$POOL_ID/providers/$PROVIDER_ID"
```

## Step 7: Update Rails Application

Update your `app/services/gemini_service.rb`:

```ruby
def self.vertex_ai_service
  @vertex_ai_service ||= begin
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

      Google::Cloud::AIPlatform.generative_ai_service do |config|
        config.credentials = authorizer
      end
    elsif Rails.application.credentials.google_service_account_key
      # Fall back to service account key
      Google::Cloud::AIPlatform.generative_ai_service do |config|
        config.credentials = service_account_credentials
      end
    else
      # Use Application Default Credentials
      Google::Cloud::AIPlatform.generative_ai_service
    end
  end
end

private

def self.fetch_fly_token
  # Fly.io provides tokens at this endpoint
  uri = URI('http://[::1]:3000/.fly/api/tokens/oidc')
  response = Net::HTTP.get_response(uri)
  response.body if response.is_a?(Net::HTTPSuccess)
end
```

## Step 8: Test the Configuration

Deploy and test:

```bash
fly deploy
fly ssh console -C "bin/rails console"
```

In the Rails console:

```ruby
# Should work without any stored credentials!
result = GeminiService.generate_tip(
  user_profile: User.first.profile_for_ai,
  category: 'Putting',
  context: {}
)
puts result
```

## Advantages Over Service Account Keys

1. **No key rotation needed** - Tokens are short-lived and auto-renewed
2. **No secrets in code** - Authentication based on runtime environment
3. **Audit trail** - Every access is logged with the app identity
4. **Environment isolation** - Different apps can't use each other's credentials
5. **Compliance friendly** - Meets most security standards (SOC2, ISO 27001)

## Rollback Plan

If you need to temporarily fall back to service account keys:

1. Keep the key in Rails credentials as backup
2. The code above already has fallback logic
3. Simply remove the WIF environment variables to use keys

## Security Best Practices

1. **Limit permissions** - Only grant necessary roles
2. **Use conditions** - Restrict by app name, environment
3. **Monitor access** - Check Cloud Logging regularly
4. **Regular audits** - Review IAM policies quarterly

## Troubleshooting

### "Permission denied" errors

- Verify the workload identity pool configuration
- Check IAM bindings are correct
- Ensure Fly.io app name matches the condition

### "Invalid token" errors

- Fly.io token endpoint must be accessible
- Check the audience string is correct
- Verify service account email is set

## Additional Resources

- [Google Cloud Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)
- [Fly.io OIDC Tokens](https://fly.io/docs/reference/openid-connect/)
- [Security Best Practices](https://cloud.google.com/iam/docs/best-practices-for-managing-workload-identity-federation)
