#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
STAGING=$(mktemp -d /private/tmp/snapforge-editor-check.XXXXXX)
APP="$STAGING/SnapForge Editor Check.app"
mkdir -p "$APP/Contents/MacOS" build/modules
xcrun swiftc -sdk "$(xcrun --show-sdk-path)" -target "$(uname -m)-apple-macos14.0" -module-cache-path build/modules SnapForge/Editing/*.swift SnapForge/ImageProcessing/*.swift SnapForge/Output/ImageOutput.swift SnapForge/Preferences/Preferences.swift Tests/EditorDemo/main.swift -o "$APP/Contents/MacOS/EditorCheck"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>CFBundleExecutable</key><string>EditorCheck</string><key>CFBundleIdentifier</key><string>com.snapforge.editor-check</string><key>CFBundleName</key><string>SnapForge Editor Check</string><key>CFBundlePackageType</key><string>APPL</string><key>LSMinimumSystemVersion</key><string>14.0</string></dict></plist>
PLIST
codesign --force --sign - "$APP"
echo "$APP"
