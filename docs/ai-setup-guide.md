# Google Cloud AI Platform Setup Guide

This guide explains how to set up AI tip generation using Google's official `google-cloud-ai_platform` gem with Vertex AI.

## Prerequisites

- Google Cloud account with billing enabled
- Rails application with credentials configured

## Step 1: Install the Gem

The gem is already added to your Gemfile. Install it with:

```bash
bundle install
```

## Step 2: Set up Google Cloud Project

1. **Create/Select Project**

   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Create a new project or select an existing one
   - Note your Project ID (you'll need this)

2. **Enable Required APIs**

   - Enable the [Vertex AI API](https://console.cloud.google.com/apis/library/aiplatform.googleapis.com)
   - Enable the [Cloud Resource Manager API](https://console.cloud.google.com/apis/library/cloudresourcemanager.googleapis.com)

3. **Set up IAM Permissions**
   - Your service account needs these roles:
     - `AI Platform User` (`roles/aiplatform.user`)
     - `Vertex AI User` (`roles/ml.admin`) - if needed

## Step 3: Authentication

Choose **Option A** for production or **Option B** for development.

### Option A: Service Account (Recommended for Production)

1. **Create Service Account**

   - Go to [IAM & Admin > Service Accounts](https://console.cloud.google.com/iam-admin/serviceaccounts)
   - Click "Create Service Account"
   - Give it a name like "golf-ai-service"
   - Grant it the roles mentioned above

2. **Download Key File**

   - Click on your service account
   - Go to "Keys" tab → "Add Key" → "Create new key"
   - Choose JSON format and download

3. **Add to Rails Credentials**

   ```bash
   rails credentials:edit
   ```

   Add your credentials:

   ```yaml
   google_cloud_project_id: 'your-project-id'
   google_service_account_key: |
     {
       "type": "service_account",
       "project_id": "your-project-id",
       "private_key_id": "abc123...",
       "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
       "client_email": "golf-ai-service@your-project.iam.gserviceaccount.com",
       "client_id": "123456789...",
       "auth_uri": "https://accounts.google.com/o/oauth2/auth",
       "token_uri": "https://oauth2.googleapis.com/token",
       "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
       "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/..."
     }
   ```

### Option B: Application Default Credentials (Development)

1. **Install gcloud CLI**

   - Download from [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
   - Follow installation instructions for your OS

2. **Authenticate**

   ```bash
   gcloud auth application-default login
   gcloud config set project YOUR-PROJECT-ID
   ```

3. **Add Project ID to Credentials**

   ```bash
   rails credentials:edit
   ```

   Add only:

   ```yaml
   google_cloud_project_id: 'your-project-id'
   ```

## Step 4: Verify Setup

1. **Check Credentials**
   Start your Rails server and check the logs for any credential warnings.

2. **Test AI Generation**

   ```ruby
   # In Rails console (rails console)
   user = User.first

   result = GeminiService.generate_tip(
     user_profile: user.profile_for_ai,
     category: 'Putting',
     context: {}
   )

   puts result
   ```

   You should see a hash with `:title`, `:content`, and `:phase` keys.

## Step 5: Queue Test AI Generation

Test the background job system:

```ruby
# In Rails console
user = User.first
GenerateTipsJob.perform_now(user.id, 2)
```

Check your logs to see the generation process and any tips created.

## Troubleshooting

### Common Issues

1. **"Project not found" error**

   - Verify your `google_cloud_project_id` in credentials
   - Ensure the project exists and billing is enabled

2. **"Permission denied" error**

   - Check that Vertex AI API is enabled
   - Verify your service account has the correct roles
   - For ADC: run `gcloud auth list` to check active account

3. **"Model not found" error**

   - Gemini Pro might not be available in your region
   - Try changing the region in `GeminiService.model_endpoint`
   - Supported regions: `us-central1`, `us-east4`, `europe-west4`

4. **Timeout errors**
   - Vertex AI can be slower than direct API calls
   - This is normal for the first request (cold start)
   - Subsequent requests should be faster

### Environment Variables Alternative

Instead of Rails credentials, you can use environment variables:

```bash
# .env or your deployment environment
GOOGLE_CLOUD_PROJECT_ID=your-project-id
GOOGLE_APPLICATION_CREDENTIALS=path/to/service-account-key.json
```

### Cost Monitoring

- Monitor usage in [Google Cloud Console > Vertex AI](https://console.cloud.google.com/vertex-ai)
- Set up billing alerts to avoid unexpected charges
- Gemini Pro pricing: ~$0.0025 per 1K input tokens, ~$0.0075 per 1K output tokens

## Next Steps

Once everything is working:

1. **Production Deployment**: Use service account method
2. **Rate Limiting**: Monitor API quotas in Cloud Console
3. **Error Monitoring**: Set up error tracking for failed generations
4. **Performance**: Consider caching popular tip requests

## Security Notes

- Never commit service account keys to version control
- Rotate service account keys regularly
- Use least-privilege IAM roles
- Monitor API access logs

## Additional Resources

- [Vertex AI Documentation](https://cloud.google.com/vertex-ai/docs)
- [Google Cloud Ruby Client Libraries](https://cloud.google.com/ruby/docs/reference)
- [Gemini API Documentation](https://cloud.google.com/vertex-ai/docs/generative-ai/model-reference/gemini)
