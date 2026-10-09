#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
SDK=$(xcrun --show-sdk-path)
STAGING=$(mktemp -d /private/tmp/snapforge-build.XXXXXX)
APP="$STAGING/SnapForge.app"
mkdir -p "$APP/Contents/MacOS" build/modules build/Release
SOURCES=(SnapForge/App/main.swift)
while IFS= read -r source; do
  [[ "$source" == "SnapForge/App/main.swift" ]] || SOURCES+=("$source")
done < <(find SnapForge -name "*.swift" -print | sort)
for ARCH in arm64 x86_64; do
  xcrun swiftc -O -sdk "$SDK" -target "$ARCH-apple-macos14.0" -module-cache-path build/modules "${SOURCES[@]}" -o "build/SnapForge-$ARCH"
done
xcrun lipo -create build/SnapForge-arm64 build/SnapForge-x86_64 -output "$APP/Contents/MacOS/SnapForge"
cp SnapForge/Resources/Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources"
cp SnapForge/Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
SIGNING_IDENTITY="${SNAPFORGE_SIGNING_IDENTITY:--}"
if [[ "$SIGNING_IDENTITY" == "-" ]]; then
  echo "Ad-hoc build: rebuilding can invalidate Screen Recording permission. Reauthorize the final installed copy."
fi
codesign --force --sign "$SIGNING_IDENTITY" "$APP"
codesign --verify --strict "$APP"
xcrun lipo -info "$APP/Contents/MacOS/SnapForge"
# Keep runnable bundles out of the synced workspace: its file provider can
# invalidate signatures by attaching Finder metadata, and LaunchServices can
# accidentally reopen that duplicate instead of the permission-approved copy.
echo "Verified app bundle: $APP"
ditto -c -k --sequesterRsrc --keepParent "$APP" build/Release/SnapForge.zip
VERIFY_DIR=$(mktemp -d /private/tmp/snapforge-verify.XXXXXX)
ditto -x -k build/Release/SnapForge.zip "$VERIFY_DIR"
codesign --verify --strict "$VERIFY_DIR/SnapForge.app"
shasum -a 256 build/Release/SnapForge.zip > build/Release/SnapForge.zip.sha256
