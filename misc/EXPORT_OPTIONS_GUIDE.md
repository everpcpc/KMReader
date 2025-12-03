# Export Options Configuration Guide

The `exportOptions.plist` file is used when exporting archives to IPA/APP files. You need to create your own configuration file based on your distribution needs.

## Quick Start

1. Copy the example file:
   ```bash
   cp misc/exportOptions.plist.example misc/exportOptions.plist
   ```

2. Edit `misc/exportOptions.plist` according to your distribution method (see examples below)

## Distribution Methods

### 1. App Store Distribution

For submitting to the App Store, Xcode recommends using `app-store-connect` method which directly uploads to App Store Connect:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>

    <!-- Optional: Your Team ID (found in Apple Developer account) -->
    <key>teamID</key>
    <string>M777UHWZA4</string>

    <!-- Optional: Upload directly to App Store Connect (usually enabled by default with app-store-connect) -->
    <key>uploadToAppStore</key>
    <true/>

    <!-- Optional: Upload symbols for crash reporting -->
    <key>uploadSymbols</key>
    <true/>
</dict>
</plist>
```

**Note:** `app-store-connect` is the recommended method by Xcode for direct uploads. Alternatively, you can use `app-store` method to export an IPA file for manual upload.

### 2. Ad Hoc Distribution

For testing on specific devices:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>ad-hoc</string>

    <key>teamID</key>
    <string>M777UHWZA4</string>

    <!-- Optional: Specify signing certificate -->
    <key>signingCertificate</key>
    <string>iPhone Distribution</string>

    <!-- Optional: Specify provisioning profile -->
    <key>provisioningProfiles</key>
    <dict>
        <key>com.everpcpc.Komga</key>
        <string>Your Ad Hoc Provisioning Profile Name</string>
    </dict>
</dict>
</plist>
```

### 3. Development Distribution

For development/testing builds:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>development</string>

    <key>teamID</key>
    <string>M777UHWZA4</string>

    <!-- Optional: Specify signing certificate -->
    <key>signingCertificate</key>
    <string>Apple Development</string>
</dict>
</plist>
```

### 4. Enterprise Distribution

For enterprise/internal distribution:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>enterprise</string>

    <key>teamID</key>
    <string>M777UHWZA4</string>

    <key>signingCertificate</key>
    <string>iPhone Distribution</string>
</dict>
</plist>
```

### 5. macOS App Distribution

For macOS apps (notarization options):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>

    <key>teamID</key>
    <string>M777UHWZA4</string>

    <!-- Optional: Notarize the app -->
    <key>notarize</key>
    <true/>
</dict>
</plist>
```

## Finding Your Information

### Team ID
- Found in your Apple Developer account: https://developer.apple.com/account
- Or in Xcode: Preferences > Accounts > Select your team

### Signing Certificate Names
Common certificate names:
- `Apple Development` - For development builds
- `Apple Distribution` - For App Store and Ad Hoc
- `iPhone Distribution` - For iOS distribution
- `Developer ID Application` - For macOS distribution outside App Store

### Provisioning Profile Names
- Found in Xcode: Preferences > Accounts > Select team > Download Manual Profiles
- Or in Apple Developer Portal: Certificates, Identifiers & Profiles

## Minimal Configuration

If you're using Automatic Signing in Xcode, you can use a minimal configuration:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>

    <key>teamID</key>
    <string>M777UHWZA4</string>
</dict>
</plist>
```

Xcode will automatically select the appropriate certificates and provisioning profiles based on your project settings.

## Automatic Upload to App Store Connect

When `uploadToAppStore` is set to `true` in `exportOptions.plist`, the export script will automatically upload the build to App Store Connect after exporting.

### Authentication Methods

**Method 1: App Store Connect API Key (Recommended for CI/CD)**

Use App Store Connect API key for automated uploads without interactive login. Set the credentials as environment variables (directly or in `.env`) before running the script:

```bash
APP_STORE_CONNECT_API_KEY_PATH=/path/to/AuthKey_XXXXXXXXXX.p8 \
APP_STORE_CONNECT_API_ISSUER_ID=YOUR_ISSUER_ID \
APP_STORE_CONNECT_API_KEY_ID=YOUR_KEY_ID \
./export.sh ./archives/KMReader-iOS_20240101_120000.xcarchive \
  exportOptions.plist \
  ./exports
```

### How to Get App Store Connect API Key

Follow these detailed steps to create and download your API key:

#### Step 1: Access App Store Connect API Keys Page

1. Go to [App Store Connect](https://appstoreconnect.apple.com/)
2. Sign in with your Apple ID (must have Admin or App Manager role)
3. Navigate to **Users and Access** → **Integrations** → **App Store Connect API**
   - Direct link: https://appstoreconnect.apple.com/access/api
4. Click the **Keys** tab

#### Step 2: Create a New API Key

1. Click the **Generate API Key** button (or **+** button)
2. Enter a **Key Name** (e.g., "KMReader CI/CD" or "Export Script")
3. Select **Access Level**:
   - **Admin**: Full access to all features
   - **App Manager**: Can manage apps and submit for review
   - **Developer**: Limited access (may not work for uploads)
   - **Recommended**: Use **App Manager** or **Admin** for uploads
4. Click **Generate**

#### Step 3: Download and Save the Key

**⚠️ IMPORTANT: You can only download the key file once!**

1. After generating, you'll see a dialog with:
   - **Issuer ID** (looks like: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`)
   - **Key ID** (looks like: `XXXXXXXXXX`)
   - **Download** button for the `.p8` file
2. **Immediately download** the `.p8` file (named like `AuthKey_XXXXXXXXXX.p8`)
3. **Save it securely** - you cannot download it again!
   - Recommended location: `~/.appstoreconnect/private_keys/`
   - Or a secure location in your project (but **DO NOT commit to git!**)
4. **Note down** the **Issuer ID** and **Key ID** - you'll need them for the script

#### Step 4: Verify Your Information

You should have:
- ✅ **Key file**: `AuthKey_XXXXXXXXXX.p8` (the `.p8` file you downloaded)
- ✅ **Key ID**: `XXXXXXXXXX` (10 characters, shown in the key name)
- ✅ **Issuer ID**: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` (UUID format)

#### Step 5: Use the API Key

Now you can use the API key in the export script by providing environment variables (or `.env`):

```bash
APP_STORE_CONNECT_API_KEY_PATH=~/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8 \
APP_STORE_CONNECT_API_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx \
APP_STORE_CONNECT_API_KEY_ID=XXXXXXXXXX \
./misc/export.sh ./archives/KMReader-iOS_xxx.xcarchive \
  misc/exportOptions.plist \
  ./exports
```

#### Security Best Practices

1. **Never commit the `.p8` file to git** - add it to `.gitignore`:
   ```
   # App Store Connect API Keys
   *.p8
   AuthKey_*.p8
   ~/.appstoreconnect/
   ```

2. **Store keys securely**:
   - Use a password manager
   - Use environment variables in CI/CD
   - Restrict file permissions: `chmod 600 AuthKey_*.p8`

3. **Rotate keys periodically**:
   - Delete old keys from App Store Connect
   - Generate new keys when team members leave

4. **Use different keys for different purposes**:
   - One key for CI/CD
   - One key for local development
   - Different keys for different apps/teams

**Method 2: Interactive Login**

If you don't provide API key credentials, `xcodebuild` will prompt for your Apple ID and password (or use App-Specific Password if 2FA is enabled).

### Environment Variables

Alternatively, you can set these environment variables instead of using command-line arguments. A template file is provided at `misc/env.example`:

**Option 1: Use the example file as a template (Recommended)**

1. Copy the example file:
   ```bash
   cp misc/env.example .env
   ```

2. Edit `.env` and fill in your actual values:
   ```bash
   # Edit .env file
   nano .env  # or use your preferred editor
   ```

3. Run the export script - it will automatically load `.env`:
   ```bash
   ./misc/export.sh ./archives/KMReader-iOS_xxx.xcarchive
   ```

   **Note:** The script automatically detects and loads `.env` file from the project root, so you don't need to manually `source .env`!

**Option 2: Set environment variables directly**

```bash
export APP_STORE_CONNECT_API_KEY_PATH="/path/to/AuthKey_XXXXXXXXXX.p8"
export APP_STORE_CONNECT_API_ISSUER_ID="YOUR_ISSUER_ID"
export APP_STORE_CONNECT_API_KEY_ID="YOUR_KEY_ID"
./misc/export.sh ./archives/KMReader-iOS_xxx.xcarchive
```

**Option 3: Inline with the command**

```bash
APP_STORE_CONNECT_API_KEY_PATH="/path/to/AuthKey_XXX.p8" \
APP_STORE_CONNECT_API_ISSUER_ID="your-issuer-id" \
APP_STORE_CONNECT_API_KEY_ID="your-key-id" \
./misc/export.sh ./archives/KMReader-iOS_xxx.xcarchive
```

**Note:** The export script automatically reads these environment variables, so no additional command-line flags are required.

## Notes

- If you don't specify `signingCertificate` or `provisioningProfiles`, Xcode will use Automatic Signing settings from your project
- The `teamID` is usually required for all distribution methods
- For App Store distribution, you may need to use `altool` or `xcrun notarytool` for notarization (macOS)
- The example file uses `app-store-connect` as default (recommended by Xcode), change it based on your needs
- `app-store-connect` method automatically uploads to App Store Connect, while `app-store` exports an IPA for manual upload
- When `uploadToAppStore` is `true`, the script will automatically upload after successful export
- App Store Connect API keys are recommended for CI/CD pipelines to avoid interactive prompts
