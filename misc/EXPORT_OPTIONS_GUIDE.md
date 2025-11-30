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

For submitting to the App Store:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>

    <!-- Optional: Your Team ID (found in Apple Developer account) -->
    <key>teamID</key>
    <string>M777UHWZA4</string>

    <!-- Optional: Upload directly to App Store Connect -->
    <key>uploadToAppStore</key>
    <true/>

    <!-- Optional: Upload symbols for crash reporting -->
    <key>uploadSymbols</key>
    <true/>
</dict>
</plist>
```

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

## Notes

- If you don't specify `signingCertificate` or `provisioningProfiles`, Xcode will use Automatic Signing settings from your project
- The `teamID` is usually required for all distribution methods
- For App Store distribution, you may need to use `altool` or `xcrun notarytool` for notarization (macOS)
- The example file uses `app-store` as default, change it based on your needs
