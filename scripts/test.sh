#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/tests build/modules
xcrun swiftc -sdk "$(xcrun --show-sdk-path)" -target "$(uname -m)-apple-macos14.0" -module-cache-path build/modules SnapForge/Capture/CaptureGeometry.swift SnapForge/Output/ImageOutput.swift SnapForge/Preferences/Preferences.swift Tests/main.swift -o build/tests/SnapForgeTests
build/tests/SnapForgeTests
