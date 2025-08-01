# Microsoft Azure Portal Setup Guide

## Overview
This guide walks you through setting up a Microsoft Azure app registration for your GoveeStatusLight application to access Microsoft Graph APIs for Teams presence and Calendar data.

## Prerequisites
- Microsoft 365 Business or Enterprise account
- Access to Azure Portal (same login as Microsoft 365)
- Admin consent permissions (or ability to request them)

## Step 1: Create App Registration

### 1.1 Access Azure Portal
1. Go to [Azure Portal](https://portal.azure.com)
2. Sign in with your Microsoft 365 account
3. Navigate to **Azure Active Directory** (or **Microsoft Entra ID**)
4. Select **App registrations** from the left menu
5. Click **+ New registration**

### 1.2 Configure Basic Settings
**Application Name:** `GoveeStatusLight`
**Supported account types:** 
- Select "Accounts in any organizational directory (Any Azure AD directory - Multitenant) and personal Microsoft accounts"

**Redirect URI:**
- Platform: **Public client/native (mobile & desktop)**
- URI: `msauth.com.yourname.goveeteamssync://auth`

> **Important:** Replace `yourname` with your actual developer identifier

Click **Register**

## Step 2: Configure API Permissions

### 2.1 Add Microsoft Graph Permissions
1. In your app registration, go to **API permissions**
2. Click **+ Add a permission**
3. Select **Microsoft Graph**
4. Choose **Delegated permissions**
5. Add these permissions:

**Required Permissions:**
- `Presence.Read` - Read user's presence information
- `Calendars.Read` - Read user's calendars  
- `User.Read` - Read user's basic profile

### 2.2 Grant Admin Consent
1. Click **Grant admin consent for [Your Organization]**
2. Click **Yes** to confirm
3. Verify all permissions show "Granted for [Your Organization]"

## Step 3: Configure Authentication

### 3.1 Platform Configuration
1. Go to **Authentication** in your app registration
2. Under **Platform configurations**, verify your redirect URI is present
3. Under **Advanced settings**:
   - ✅ **Allow public client flows**: Enable this
   - ✅ **Live SDK support**: Enable this

### 3.2 Supported Account Types
Ensure "Accounts in any organizational directory and personal Microsoft accounts" is selected

## Step 4: Get Application Details

### 4.1 Copy Client ID
1. Go to **Overview** in your app registration
2. Copy the **Application (client) ID**
3. This is your `CLIENT_ID` for the app

### 4.2 Update Application Code
In your Xcode project, update the configuration:

**File:** `StatusLight/Services/MicrosoftGraphService.swift`

```swift
struct MicrosoftGraphConfig {
    static let clientId = "YOUR_ACTUAL_CLIENT_ID_HERE" // Replace with copied client ID
    static let redirectURI = "msauth.com.yourname.goveeteamssync://auth" // Use your actual redirect URI
    // ... rest remains the same
}
```

## Step 5: Configure URL Scheme in Xcode

### 5.1 Add URL Scheme
1. Open your Xcode project
2. Select your app target
3. Go to **Info** tab
4. Expand **URL Types**
5. Click **+** to add new URL Type
6. Set **URL Schemes** to: `msauth.com.yourname.goveeteamssync`

### 5.2 Update Info.plist
Add this to your `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>Microsoft Graph Authentication</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>msauth.com.yourname.goveeteamssync</string>
        </array>
    </dict>
</array>
```

## Step 6: Test Authentication

### 6.1 Build and Run
1. Update the client ID in your code
2. Build and run your app in Xcode
3. Click the authentication button
4. You should see a Microsoft login prompt
5. After successful login, the app should show "Connected" status

### 6.2 Verify Permissions
After authentication, the app should be able to:
- ✅ Read your Teams presence status
- ✅ Access your calendar events
- ✅ Display your basic profile info

## Troubleshooting

### Common Issues

**"Client ID not configured" Error:**
- Ensure you've updated `MicrosoftGraphConfig.clientId` with your actual client ID

**"Redirect URI mismatch" Error:**
- Verify the redirect URI in Azure matches exactly what's in your code
- Check URL scheme is properly configured in Xcode

**"Permission denied" Error:**
- Ensure all required permissions are granted
- Try granting admin consent again
- Check if your organization requires admin approval for new apps

**"Authentication failed" Error:**
- Verify your Microsoft 365 account has proper licenses
- Check if conditional access policies are blocking the app
- Try authentication from a different network

### Verification Checklist

Before testing:
- [ ] App registration created in Azure Portal
- [ ] Client ID copied and updated in code
- [ ] All required permissions added and consented
- [ ] Redirect URI matches between Azure and code
- [ ] URL scheme configured in Xcode
- [ ] Public client flows enabled
- [ ] Build and run successful

## Security Best Practices

1. **Never commit secrets:** The client ID is not a secret for public clients, but never commit any client secrets
2. **Use Keychain:** Tokens are automatically stored in macOS Keychain
3. **Token refresh:** The app handles automatic token refresh
4. **Minimal permissions:** Only request permissions you actually need
5. **Regular review:** Periodically review and clean up app registrations

## Rate Limits

Microsoft Graph has the following rate limits for presence and calendar APIs:
- **Presence API:** 1,500 requests per minute per user
- **Calendar API:** 10,000 requests per 10 minutes per user

Your app is configured to poll every 30 seconds, well within these limits.

## Next Steps

After completing this setup:
1. Test authentication in your app
2. Verify Teams presence detection works
3. Confirm calendar events are retrieved
4. Move on to Phase 3 (Calendar Integration) or Phase 4 (Govee Integration)

## Support Resources

- [Microsoft Graph Documentation](https://docs.microsoft.com/en-us/graph/)
- [Azure App Registration Guide](https://docs.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app)
- [Microsoft Graph Permissions Reference](https://docs.microsoft.com/en-us/graph/permissions-reference)