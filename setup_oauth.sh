#!/bin/bash

echo "=== Google OAuth Setup for Personal Golf App ==="
echo ""
echo "Step 1: Create OAuth Credentials in Google Cloud Console"
echo "--------------------------------------------------------"
echo "1. Go to: https://console.cloud.google.com/apis/credentials?project=jt-designs-79"
echo "2. Click '+ CREATE CREDENTIALS' → 'OAuth client ID'"
echo "3. Configure:"
echo "   - Application type: Web application"
echo "   - Name: Personal Golf App"
echo "   - Authorized JavaScript origins:"
echo "     • https://golf-tip-app.fly.dev"
echo "     • http://localhost:3000"
echo "   - Authorized redirect URIs:"
echo "     • https://golf-tip-app.fly.dev/auth/google_oauth2/callback"
echo "     • http://localhost:3000/auth/google_oauth2/callback"
echo ""
echo "4. Click 'CREATE' and copy the Client ID and Client Secret"
echo ""
echo "Step 2: Enter your credentials"
echo "-------------------------------"
read -p "Enter your Google Client ID: " CLIENT_ID
read -p "Enter your Google Client Secret: " CLIENT_SECRET

echo ""
echo "Setting secrets in Fly.io..."
fly secrets set GOOGLE_CLIENT_ID="$CLIENT_ID" GOOGLE_CLIENT_SECRET="$CLIENT_SECRET"

echo ""
echo "✅ OAuth setup complete!"
echo ""
echo "Your app should now support Google Sign-In at:"
echo "https://golf-tip-app.fly.dev/"
