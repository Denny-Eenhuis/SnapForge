#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
XCODE_TEST_DIR=$(mktemp -d /private/tmp/snapforge-xctest.XXXXXX)
xcodebuild -quiet -project SnapForge.xcodeproj -scheme SnapForge -destination "platform=macOS,arch=$(uname -m)" -derivedDataPath "$XCODE_TEST_DIR/DerivedData" -resultBundlePath "$XCODE_TEST_DIR/CoreTests.xcresult" test > "$XCODE_TEST_DIR/test.log" 2>&1 || { cat "$XCODE_TEST_DIR/test.log"; exit 1; }
xcrun xcresulttool get test-results summary --path "$XCODE_TEST_DIR/CoreTests.xcresult"
echo "XCTest result bundle: $XCODE_TEST_DIR/CoreTests.xcresult"
