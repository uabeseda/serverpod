# Multi-Client ID Support for Google Authentication

## Overview

Serverpod Auth's Google authentication now supports multiple client IDs, enabling users to authenticate from Web, iOS, macOS, and Android platforms using their respective Google Client IDs.

## Why Multiple Client IDs?

When using Google Sign-In with native mobile apps, each platform uses its own Google Client ID:

- **Web apps** use the Web Client ID
- **iOS apps** use the iOS Client ID
- **macOS apps** use the macOS Client ID (or iOS ID for Flutter apps)
- **Android apps** use the Android Client ID

Each platform's client ID appears in the `aud` (audience) claim of the ID token sent to your backend. Previously, the Serverpod backend only accepted tokens with the Web Client ID, causing native app authentication to fail with `invalidCredentials`.

## The Problem

Here's what happens when a native app tries to authenticate:

```
1. User (iOS) → "Sign in with Google"
2. iOS app → Google OAuth (with clientId = iOS_CLIENT_ID)
3. Google → issues ID Token (aud = iOS_CLIENT_ID)
4. iOS app → sends token to Serverpod backend
5. Backend → reads google_client_secret.json (client_id = Web_CLIENT_ID)
6. Backend → validates: token.aud (iOS_CLIENT_ID) ≠ config.client_id (Web_CLIENT_ID)
7. Backend → returns "invalidCredentials" ❌
```

## The Solution

Configure your backend to accept multiple client IDs by adding the `additional_client_ids` field to your Google configuration.

---

## Configuration Guide

### Step 1: Obtain Client IDs from Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project
3. Navigate to **APIs & Services > Credentials**
4. Create OAuth 2.0 Client IDs for each platform you need:
   - **Web application** (required - this is your primary client)
   - **iOS application** (if you have an iOS app)
   - **Android application** (if you have an Android app)

**Important Notes**:
- The **Web Client ID** should be your primary `client_id` because it has a `client_secret` needed for server-side API access
- iOS/macOS/Android client IDs are public and don't have secrets
- You can find your app's client ID in:
  - **iOS**: `GoogleService-Info.plist` → `CLIENT_ID`
  - **Android**: `google-services.json` → `client_id`

### Step 2: Update Server Configuration

You can configure multi-client ID support using either `google_client_secret.json` or `passwords.yaml`.

#### Option A: Using `google_client_secret.json`

Edit `config/google_client_secret.json` and add the `additional_client_ids` field:

```json
{
  "web": {
    "client_id": "123456-web.apps.googleusercontent.com",
    "client_secret": "GOCSPX-your-secret-here",
    "redirect_uris": [
      "http://localhost:8080/auth/google/callback",
      "https://yourdomain.com/auth/google/callback"
    ],
    "additional_client_ids": [
      "123456-ios.apps.googleusercontent.com",
      "123456-android.apps.googleusercontent.com"
    ]
  }
}
```

#### Option B: Using `passwords.yaml`

Update the `googleClientSecret` field in `config/passwords.yaml`:

```yaml
development:
  googleClientSecret: |
    {
      "web": {
        "client_id": "123456-web.apps.googleusercontent.com",
        "client_secret": "GOCSPX-your-secret-here",
        "redirect_uris": ["http://localhost:8080/auth/callback"],
        "additional_client_ids": [
          "123456-ios.apps.googleusercontent.com",
          "123456-android.apps.googleusercontent.com"
        ]
      }
    }
```

### Step 3: Restart Your Server

No code changes are needed. Simply restart your Serverpod server to load the new configuration:

```bash
serverpod restart
```

### Step 4: Test Authentication

Test authentication from each platform:

1. **Web** → Should work as before
2. **iOS** → Should now work with the iOS client ID
3. **Android** → Should now work with the Android client ID
4. **macOS** → Should work (often uses iOS client ID for Flutter apps)

---

## Backward Compatibility

✅ **This feature is fully backward compatible!**

- Existing `google_client_secret.json` files work unchanged
- The `additional_client_ids` field is completely optional
- If omitted, behavior is identical to the previous version
- Empty array `[]` also works and means "no additional IDs"

**Example of backward-compatible config:**
```json
{
  "web": {
    "client_id": "your-web-client-id",
    "client_secret": "your-secret",
    "redirect_uris": ["http://localhost:8080/callback"]
  }
}
```

This continues to work exactly as before - no changes required!

---

## Troubleshooting

### Problem: Authentication fails with "Client ID doesn't match"

**Check the server logs** for the actual client ID received:

```
Client ID doesn't match. Received: 123456-ios.apps.googleusercontent.com,
Expected one of: 123456-web.apps.googleusercontent.com
```

**Solution**: Add the iOS client ID to `additional_client_ids` in your configuration.

### Problem: Don't know which Client ID to use

**Web Client ID** (primary `client_id`):
- Download from Google Cloud Console > Credentials
- Has both `client_id` and `client_secret`
- Used for server-side API access

**iOS/Android Client ID** (additional IDs):
- Found in your mobile app's configuration files:
  - iOS: `GoogleService-Info.plist` → `CLIENT_ID`
  - Android: `google-services.json` → `client > oauth_client > client_id`
- Public IDs without secrets
- Used only for validating authentication tokens

### Problem: How to test with multiple environments

Create different configurations for each environment:

**`passwords.yaml`:**
```yaml
development:
  googleClientSecret: |
    { "web": { "client_id": "dev-web-id", ... } }

staging:
  googleClientSecret: |
    { "web": { "client_id": "staging-web-id", ... } }

production:
  googleClientSecret: |
    { "web": { "client_id": "prod-web-id", ... } }
```

---

## Security Considerations

### ✅ Safe Practices

1. **Only add client IDs you control** - Never add third-party client IDs
2. **Keep the configuration file secure** - Don't commit `google_client_secret.json` to version control
3. **Use environment variables in production** - Store sensitive data in `passwords.yaml` or environment variables
4. **Validate on both client and server** - Don't rely only on client-side validation

### 🔒 How It Works

- The `additional_client_ids` are used **only for authentication validation**
- They verify that the ID token is genuine and issued for your app
- API access still uses the primary Web client credentials
- All configured client IDs are validated strictly (no wildcards)
- Unknown client IDs are rejected

### ⚠️ What NOT to Do

- ❌ Don't share your `client_secret` with anyone
- ❌ Don't add client IDs from other projects or developers
- ❌ Don't commit secrets to version control
- ❌ Don't expose `client_secret` in logs or error messages

---

## Example: Complete Setup for Multi-Platform App

Here's a complete example for an app with Web, iOS, and Android clients:

### 1. Google Cloud Console Setup

Create three OAuth 2.0 Client IDs:

1. **Web Client**
   - Application type: Web application
   - Name: "My App Web"
   - Authorized redirect URIs: `https://myapp.com/auth/google/callback`
   - Result: `123456-web.apps.googleusercontent.com` + secret

2. **iOS Client**
   - Application type: iOS
   - Name: "My App iOS"
   - Bundle ID: `com.example.myapp`
   - Result: `123456-ios.apps.googleusercontent.com` (no secret)

3. **Android Client**
   - Application type: Android
   - Name: "My App Android"
   - Package name: `com.example.myapp`
   - SHA-1: Your app's signing certificate
   - Result: `123456-android.apps.googleusercontent.com` (no secret)

### 2. Server Configuration

**`config/google_client_secret.json`:**
```json
{
  "web": {
    "client_id": "123456-web.apps.googleusercontent.com",
    "client_secret": "GOCSPX-abcdefghijklmnop",
    "redirect_uris": [
      "https://myapp.com/auth/google/callback"
    ],
    "additional_client_ids": [
      "123456-ios.apps.googleusercontent.com",
      "123456-android.apps.googleusercontent.com"
    ]
  }
}
```

### 3. Client App Configuration

**iOS** (`GoogleService-Info.plist`):
```xml
<key>CLIENT_ID</key>
<string>123456-ios.apps.googleusercontent.com</string>
```

**Android** (`app/build.gradle`):
```gradle
// Uses google-services.json which contains:
// "client_id": "123456-android.apps.googleusercontent.com"
```

**Web** (Flutter web or JavaScript):
```dart
// Use the Web Client ID
const webClientId = '123456-web.apps.googleusercontent.com';
```

### 4. Authentication Flow

Now all platforms can authenticate successfully:

```
Web:     aud = "123456-web.apps.googleusercontent.com"     ✅ Matches primary client_id
iOS:     aud = "123456-ios.apps.googleusercontent.com"     ✅ Matches additional_client_ids[0]
Android: aud = "123456-android.apps.googleusercontent.com" ✅ Matches additional_client_ids[1]
Unknown: aud = "unknown.apps.googleusercontent.com"        ❌ Rejected
```

---

## Migration Path

### For Users NOT Using Native Apps

**Action Required**: ✅ None

Your existing configuration continues to work without any changes.

### For Users With Native Apps (Currently Failing)

If your iOS/macOS/Android authentication is currently failing:

**Current Problem**: `Client ID doesn't match` errors

**Solution** (3 steps):

1. **Find your client IDs**
   ```bash
   # iOS: Check GoogleService-Info.plist
   # Android: Check google-services.json
   ```

2. **Update your server configuration**
   Add to `config/google_client_secret.json`:
   ```json
   "additional_client_ids": [
     "YOUR_IOS_CLIENT_ID",
     "YOUR_ANDROID_CLIENT_ID"
   ]
   ```

3. **Restart your server**
   ```bash
   serverpod restart
   ```

**That's it!** No code changes needed in your client apps.

---

## FAQ

**Q: Do I need to change my client app code?**
A: No. This is a server-side only change. Your client apps continue using the same authentication flow.

**Q: Can I add client IDs later?**
A: Yes. You can add or remove client IDs at any time by updating the configuration and restarting the server.

**Q: What happens to existing users?**
A: Nothing changes. Existing user accounts work across all platforms. The user ID is the same regardless of which client ID authenticated.

**Q: Can I use the same client ID for multiple platforms?**
A: While technically possible, it's not recommended. Each platform should have its own client ID for better security and tracking.

**Q: Do I need a separate client_secret for each platform?**
A: No. Only the Web client has a secret. iOS/Android/macOS client IDs are public and don't have secrets.

**Q: How many additional_client_ids can I add?**
A: There's no hard limit, but typically you'll have 2-4 (iOS, macOS, Android, maybe a different web environment).

**Q: Does this affect refresh tokens or API access?**
A: No. Refresh tokens and API access still use the primary Web client credentials. The additional IDs only validate incoming authentication tokens.

**Q: Can I use this with the passwords.yaml file?**
A: Yes! Both `google_client_secret.json` and `passwords.yaml` support the `additional_client_ids` field.

**Q: Is this a breaking change?**
A: No. This feature is 100% backward compatible. Existing configurations work without modification.

---

## Technical Details

For developers interested in the implementation:

### Validation Logic

The server validates the `aud` claim from Google's ID token:

```dart
// Before: Only accepted primary client ID
if (data['aud'] != clientId) {
  return invalidCredentials;
}

// After: Accepts primary OR additional client IDs
if (!clientSecret.isValidClientId(data['aud'])) {
  return invalidCredentials;
}
```

### Configuration Parsing

The server parses the optional `additional_client_ids` field:

```dart
List<String> additionalClientIds = [];
var webAdditionalClientIds = web['additional_client_ids'];
if (webAdditionalClientIds != null) {
  additionalClientIds = (webAdditionalClientIds as List)
      .cast<String>()
      .where((id) => id.isNotEmpty)
      .toList();
}
```

### Helper Methods

Two helper methods simplify validation:

```dart
class GoogleClientSecret {
  // Check if a specific client ID is valid
  bool isValidClientId(String clientIdToCheck) {
    if (clientIdToCheck == clientId) return true;
    return additionalClientIds.contains(clientIdToCheck);
  }

  // Get all valid client IDs
  List<String> get allClientIds => [clientId, ...additionalClientIds];
}
```

---

## Support

If you encounter issues:

1. Check the [Troubleshooting](#troubleshooting) section above
2. Enable debug logging to see detailed error messages
3. Verify your client IDs in Google Cloud Console
4. Check that your configuration JSON is valid
5. Open an issue on [GitHub](https://github.com/serverpod/serverpod) if problems persist

---

## Related Documentation

- [Google Sign-In Documentation](https://developers.google.com/identity/sign-in/web)
- [Serverpod Authentication Guide](https://docs.serverpod.dev)
- [OAuth 2.0 Best Practices](https://tools.ietf.org/html/rfc6749)
