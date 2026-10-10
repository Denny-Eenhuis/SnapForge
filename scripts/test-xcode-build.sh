#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
XCODE_CHECK_DIR=$(mktemp -d /private/tmp/snapforge-xcode-check.XXXXXX)
xcodebuild -version
for CONFIG in Debug Release; do
  xcodebuild -quiet -project SnapForge.xcodeproj -scheme SnapForge -configuration "$CONFIG" -destination 'generic/platform=macOS' -derivedDataPath "$XCODE_CHECK_DIR" ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO build > "$XCODE_CHECK_DIR/$CONFIG.log" 2>&1 || { cat "$XCODE_CHECK_DIR/$CONFIG.log"; exit 1; }
  APP="$XCODE_CHECK_DIR/Build/Products/$CONFIG/SnapForge.app"
  codesign --verify --strict "$APP"
  xcrun lipo -info "$APP/Contents/MacOS/SnapForge"
  cmp SnapForge/Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
  echo "PASS: $CONFIG universal Xcode build, signature and icon"
done
echo "Validation products/logs: $XCODE_CHECK_DIR"
# Never install or launch these validation bundles: the permission-approved
# installed app should stay unchanged during build checks.
