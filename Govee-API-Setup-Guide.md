# Govee API Key Setup Guide

## Overview
This guide walks you through obtaining a Govee API key and configuring it in your GoveeStatusLight application to control your smart lights based on Microsoft Teams status.

## Prerequisites
- **Govee Home App** installed on your mobile device (iOS/Android)
- **Govee Smart Lights** already set up and working in the Govee Home app
- **Valid email address** for API key application

## Step 1: Install and Set Up Govee Home App

### 1.1 Download the App
- **iOS**: Download from the App Store
- **Android**: Download from Google Play Store

### 1.2 Create Account and Add Devices
1. Open the Govee Home app
2. Create an account or sign in
3. Add your Govee smart lights to the app
4. Ensure all devices are working properly in the app
5. Test that you can control lights (on/off, color changes) from the app

## Step 2: Apply for Govee API Key

### 2.1 Access API Key Application
1. Open the **Govee Home App**
2. Go to **Profile** (bottom right corner)
3. Tap **Settings** ⚙️
4. Scroll down and find **"Apply for API Key"**
5. Tap **"Apply for API Key"**

### 2.2 Fill Out Application Form
You'll need to provide:
- **Name**: Your full name
- **Email**: Valid email address (you'll receive the API key here)
- **Purpose**: Explain your use case (e.g., "Home automation integration with Microsoft Teams status")
- **Company/Organization**: Optional, can put "Personal Use"
- **Additional Details**: Briefly describe your project

**Example Application:**
```
Name: John Smith
Email: john.smith@email.com
Purpose: Integrating Govee smart lights with Microsoft Teams status for home office automation
Company: Personal Use
Details: Creating a macOS application that changes light colors based on Teams availability status (Available=Green, Busy=Red, Away=Yellow, etc.)
```

### 2.3 Submit Application
1. Review your information
2. Tap **Submit Application**
3. You'll see a confirmation message

## Step 3: Wait for API Key Approval

### 3.1 Processing Time
- **Typical wait time**: 1-3 business days
- **Maximum wait time**: Up to 7 business days
- Govee reviews applications manually

### 3.2 Check Your Email
- Monitor your email inbox (including spam folder)
- Look for an email from Govee with subject like "Govee API Key Application"
- The email will contain your unique API key

## Step 4: Configure API Key in StatusLight App

### 4.1 Locate Your API Key
When you receive the email, your API key will look like:
```
12345678-abcd-1234-efgh-123456789012
```
**Important**: This is a unique 32-character string with dashes

### 4.2 Add API Key to StatusLight App
1. **Launch StatusLight app** from your menu bar
2. **Click Settings** in the status window
3. **Govee API Configuration section**:
   - Click in the **"API Key"** secure text field
   - **Paste your API key** (Cmd+V)
   - Click **"Configure API Key"** button
4. **Wait for validation**:
   - The app will test your API key
   - If successful, you'll see "✅ API Key configured successfully"
   - The status indicator will turn green

### 4.3 Verify Device Discovery
After successful API key configuration:
- The app automatically discovers your Govee devices
- Check the **"Connected Devices"** section
- You should see a list of your smart lights
- Each device shows: Name, Model (SKU), and connection status

## Step 5: Test Light Control

### 5.1 Verify Integration
1. **Change your Teams status** (Available, Busy, Away, Do Not Disturb)
2. **Watch your lights change colors**:
   - 🟢 **Available**: Green
   - 🔴 **Busy/In a Call**: Red
   - 🟡 **Away**: Yellow
   - 🟣 **Do Not Disturb**: Purple
   - ⚪ **Unknown/Offline**: White

### 5.2 Manual Testing
You can also test individual devices through the app's interface or by changing your Teams status manually.

## Troubleshooting

### Common Issues

#### "API Key Invalid" Error
- **Check format**: Ensure you copied the complete API key with dashes
- **Check email**: Make sure you're using the exact key from Govee's email
- **Check expiration**: API keys don't expire, but double-check the email date

#### "No Devices Found" Error
- **Verify Govee Home App**: Ensure devices work in the official app
- **Check WiFi**: Devices must be connected to the same network
- **Wait time**: Device discovery can take 30-60 seconds

#### "Rate Limit Exceeded" Error
- **Govee limits**: 10 requests per minute maximum
- **Wait period**: Wait 1 minute before trying again
- **App handling**: StatusLight respects rate limits automatically

#### API Key Application Rejected
- **Reapply**: You can submit a new application
- **Improve description**: Provide more detail about your use case
- **Contact support**: Email Govee support if repeatedly rejected

### Support Resources

- **Govee Support**: support@govee.com
- **Govee Developer Documentation**: [https://developer.govee.com](https://developer.govee.com)
- **API Rate Limits**: 10 requests per minute
- **Supported Devices**: Most Wi-Fi enabled Govee lights (check compatibility in Govee Home app)

## Security Notes

### API Key Security
- ✅ **StatusLight stores your API key securely** in macOS Keychain
- ✅ **Never share your API key** with others
- ✅ **Never commit API keys to code repositories**
- ✅ **Each user needs their own API key**

### Network Security
- Your API key allows control of your smart lights
- Keep your home network secure
- The StatusLight app only makes necessary API calls

## Advanced Configuration

### Multiple Device Control
- StatusLight automatically discovers all compatible devices
- You can control multiple lights simultaneously
- All lights will change to match your Teams status

### Color Customization
The app uses these default color mappings:
- Available: `#00FF00` (Green)
- Busy: `#FF0000` (Red)
- Away: `#FFFF00` (Yellow)
- Do Not Disturb: `#800080` (Purple)

Future versions may allow color customization.

## Next Steps

Once your Govee API key is configured:
1. ✅ **Test the integration** with different Teams statuses
2. ✅ **Verify all your devices** are discovered and controllable
3. ✅ **Enjoy automated lighting** that matches your work status!

The StatusLight app will now automatically change your Govee smart lights based on your Microsoft Teams presence, creating a seamless work-from-home experience.