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
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
xcrun lipo -info "$APP/Contents/MacOS/SnapForge"
ditto "$APP" build/Release/SnapForge.app
# File-provider folders can attach Finder metadata to copied app bundles.
if xattr -p com.apple.FinderInfo build/Release/SnapForge.app >/dev/null 2>&1; then
  xattr -d com.apple.FinderInfo build/Release/SnapForge.app
fi
codesign --verify --strict build/Release/SnapForge.app
ditto -c -k --sequesterRsrc --keepParent "$APP" build/Release/SnapForge.zip
VERIFY_DIR=$(mktemp -d /private/tmp/snapforge-verify.XXXXXX)
ditto -x -k build/Release/SnapForge.zip "$VERIFY_DIR"
codesign --verify --strict "$VERIFY_DIR/SnapForge.app"
shasum -a 256 build/Release/SnapForge.zip > build/Release/SnapForge.zip.sha256
