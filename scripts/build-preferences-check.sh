#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP=$(mktemp -d /private/tmp/snapforge-preferences-check.XXXXXX)/SnapForgePreferencesCheck.app
mkdir -p "$APP/Contents/MacOS" build/modules
xcrun swiftc -sdk "$(xcrun --show-sdk-path)" -target "$(uname -m)-apple-macos14.0" -module-cache-path build/modules SnapForge/Preferences/Preferences.swift SnapForge/Output/ImageOutput.swift Tests/PreferencesDemo/main.swift -o "$APP/Contents/MacOS/PreferencesCheck"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>PreferencesCheck</string>
<key>CFBundleIdentifier</key><string>com.snapforge.preferences-validation</string>
<key>CFBundleName</key><string>SnapForgePreferencesCheck</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
echo "$APP"
