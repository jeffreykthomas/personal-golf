# Deployment Guide

## Overview

This guide covers deploying the Personal Golf PWA as an open-source project. It includes local development setup, Firebase configuration, and production deployment steps.

## Prerequisites

### Required Tools

- Node.js 18+ and npm/yarn
- Python 3.9+ and pip
- Firebase CLI: `npm install -g firebase-tools`
- Google Cloud SDK: [Install gcloud](https://cloud.google.com/sdk/docs/install)
- Git

### Accounts Needed

- Google Cloud Platform account
- Firebase project (created through GCP)
- Gemini API access

## Local Development Setup

### 1. Clone Repository

```bash
git clone https://github.com/yourusername/personal-golf.git
cd personal-golf
```

### 2. Install Dependencies

#### Frontend (Quasar PWA)

```bash
# Install Quasar dependencies
yarn install
# or
npm install
```

#### Firebase Functions

```bash
cd functions
npm install
cd ..
```

#### Cloud Functions (Python)

```bash
cd cloud_functions
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
cd ..
```

### 3. Environment Configuration

#### Create `.env.local` for Quasar

```bash
# .env.local
VITE_FIREBASE_API_KEY=your-api-key
VITE_FIREBASE_AUTH_DOMAIN=your-auth-domain
VITE_FIREBASE_PROJECT_ID=your-project-id
VITE_FIREBASE_STORAGE_BUCKET=your-storage-bucket
VITE_FIREBASE_MESSAGING_SENDER_ID=your-sender-id
VITE_FIREBASE_APP_ID=your-app-id
VITE_FIREBASE_MEASUREMENT_ID=your-measurement-id
```

#### Firebase Functions Environment

```bash
# Set environment variables for functions
firebase functions:config:set \
  gemini.api_key="your-gemini-api-key" \
  weather.api_key="your-weather-api-key"
```

#### Cloud Functions `.env`

```bash
# cloud_functions/.env
GEMINI_API_KEY=your-gemini-api-key
GCP_PROJECT=your-project-id
```

### 4. Firebase Setup

#### Initialize Firebase

```bash
firebase login
firebase init

# Select:
# - Firestore
# - Functions
# - Hosting
# - Storage
# - Emulators (for local development)
```

#### Firestore Rules

```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own profile
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;

      // User's private collections
      match /{subcollection}/{document} {
        allow read, write: if request.auth.uid == userId;
      }
    }

    // Tips are public read, authenticated write
    match /tips/{tipId} {
      allow read: if true;
      allow create: if request.auth != null;
      allow update: if request.auth != null &&
        (request.auth.uid == resource.data.author ||
         request.auth.token.admin == true);
      allow delete: if request.auth.uid == resource.data.author;
    }

    // Courses are public read, authenticated contribute
    match /courses/{courseId} {
      allow read: if true;
      allow write: if request.auth != null;

      match /tips/{tipId} {
        allow read: if true;
        allow create: if request.auth != null;
        allow update: if request.auth.uid == resource.data.author;
      }
    }
  }
}
```

#### Storage Rules

```javascript
// storage.rules
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // User uploads
    match /users/{userId}/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth.uid == userId &&
        request.resource.size < 5 * 1024 * 1024; // 5MB limit
    }

    // Course images
    match /courses/{courseId}/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null &&
        request.resource.size < 10 * 1024 * 1024; // 10MB limit
    }
  }
}
```

### 5. Local Development

#### Start Emulators

```bash
# Terminal 1: Firebase emulators
firebase emulators:start

# Terminal 2: Quasar dev server
quasar dev -m pwa

# Terminal 3: Cloud Functions (if testing locally)
cd cloud_functions
functions-framework --target=generate_tip --debug
```

#### Emulator Configuration

```json
// firebase.json
{
  "emulators": {
    "auth": {
      "port": 9099
    },
    "functions": {
      "port": 5001
    },
    "firestore": {
      "port": 8080
    },
    "storage": {
      "port": 9199
    },
    "ui": {
      "enabled": true,
      "port": 4000
    }
  }
}
```

## Production Deployment

### 1. Build PWA

```bash
# Build for production
quasar build -m pwa

# Output will be in dist/pwa
```

### 2. Deploy Firebase Services

#### Deploy Everything

```bash
# Deploy all services
firebase deploy

# Or deploy individually
firebase deploy --only hosting
firebase deploy --only functions
firebase deploy --only firestore:rules
firebase deploy --only storage:rules
```

#### Deploy Specific Functions

```bash
# Deploy single function
firebase deploy --only functions:createUserProfile

# Deploy function group
firebase deploy --only functions:userManagement
```

### 3. Deploy Cloud Functions (Python)

#### Configure gcloud

```bash
gcloud auth login
gcloud config set project your-project-id
```

#### Deploy Functions

```bash
cd cloud_functions

# Deploy tip generation function
gcloud functions deploy generate_tip \
  --runtime python39 \
  --trigger-http \
  --allow-unauthenticated \
  --env-vars-file .env.yaml \
  --memory 512MB \
  --timeout 60s

# Deploy pattern analysis
gcloud functions deploy analyze_user_patterns \
  --runtime python39 \
  --trigger-http \
  --allow-unauthenticated \
  --env-vars-file .env.yaml
```

### 4. Configure Custom Domain (Optional)

#### In Firebase Console

1. Go to Hosting
2. Add custom domain
3. Verify ownership
4. Update DNS records

#### SSL Certificate

- Automatically provisioned by Firebase
- Takes 24-48 hours to activate

### 5. Set Up CI/CD

#### GitHub Actions Workflow

```yaml
# .github/workflows/deploy.yml
name: Deploy to Firebase

on:
  push:
    branches: [main]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'

      - name: Install dependencies
        run: |
          npm install -g @quasar/cli
          yarn install

      - name: Build PWA
        run: quasar build -m pwa
        env:
          VITE_FIREBASE_API_KEY: ${{ secrets.FIREBASE_API_KEY }}
          VITE_FIREBASE_AUTH_DOMAIN: ${{ secrets.FIREBASE_AUTH_DOMAIN }}
          VITE_FIREBASE_PROJECT_ID: ${{ secrets.FIREBASE_PROJECT_ID }}
          VITE_FIREBASE_STORAGE_BUCKET: ${{ secrets.FIREBASE_STORAGE_BUCKET }}
          VITE_FIREBASE_MESSAGING_SENDER_ID: ${{ secrets.FIREBASE_MESSAGING_SENDER_ID }}
          VITE_FIREBASE_APP_ID: ${{ secrets.FIREBASE_APP_ID }}

      - name: Deploy to Firebase Hosting
        uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: '${{ secrets.GITHUB_TOKEN }}'
          firebaseServiceAccount: '${{ secrets.FIREBASE_SERVICE_ACCOUNT }}'
          channelId: live
          projectId: ${{ secrets.FIREBASE_PROJECT_ID }}
```

## Monitoring & Maintenance

### 1. Enable Monitoring

#### Firebase Console

- Performance Monitoring
- Crashlytics
- Analytics
- Cloud Logging

#### Set Up Alerts

```bash
# Function errors
gcloud alpha monitoring policies create \
  --notification-channels=your-channel-id \
  --display-name="Function Errors" \
  --condition-display-name="Error rate > 1%" \
  --condition-filter='resource.type="cloud_function"
    AND metric.type="cloudfunctions.googleapis.com/function/error_count"'
```

### 2. Backup Strategy

#### Firestore Backups

```bash
# Schedule daily backups
gcloud firestore export gs://your-backup-bucket/$(date +%Y%m%d) \
  --collection-ids='users,tips,courses'

# Create backup schedule
gcloud scheduler jobs create app-engine backup-firestore \
  --schedule="0 2 * * *" \
  --time-zone="America/New_York" \
  --uri="https://firestore.googleapis.com/v1/projects/YOUR_PROJECT_ID/databases/(default)/exportDocuments"
```

### 3. Security Checklist

- [ ] API keys restricted by domain
- [ ] Firebase App Check enabled
- [ ] Security rules tested
- [ ] Environment variables secured
- [ ] CORS properly configured
- [ ] Rate limiting implemented
- [ ] Input validation on all endpoints

## Troubleshooting

### Common Issues

#### 1. CORS Errors

```javascript
// In Cloud Functions
exports.corsEnabledFunction = functions.https.onRequest((req, res) => {
  res.set('Access-Control-Allow-Origin', 'https://yourdomain.com');
  res.set('Access-Control-Allow-Methods', 'GET, POST');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  // Handle actual request
});
```

#### 2. Cold Start Issues

- Keep functions warm with scheduled pings
- Minimize dependencies
- Use lazy imports for heavy libraries

#### 3. Quota Limits

- Monitor usage in GCP Console
- Implement client-side rate limiting
- Cache expensive operations

## Cost Optimization

### Free Tier Limits (as of 2024)

- Firestore: 50K reads, 20K writes, 20K deletes per day
- Cloud Functions: 2M invocations per month
- Firebase Hosting: 10GB storage, 360MB/day transfer
- Cloud Storage: 5GB storage, 1GB/day download

### Cost Reduction Tips

1. Use Firestore bundles for static data
2. Implement aggressive caching
3. Optimize image sizes before upload
4. Use Cloud CDN for media files
5. Archive old data to Cloud Storage

## Contributing Guidelines

### For Contributors

1. Fork the repository
2. Create feature branch
3. Follow code style guidelines
4. Write tests for new features
5. Update documentation
6. Submit pull request

### Code Style

- ESLint configuration provided
- Prettier for formatting
- TypeScript strict mode
- Python: Follow PEP 8

### Testing Requirements

- Unit tests for functions
- Integration tests for API endpoints
- E2E tests for critical user flows
- Minimum 70% code coverage
