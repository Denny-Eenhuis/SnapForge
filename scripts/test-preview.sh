#!/bin/bash
# Requires a logged-in macOS graphical session; opens a synthetic preview briefly.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/tests build/modules
xcrun swiftc -sdk "$(xcrun --show-sdk-path)" -target "$(uname -m)-apple-macos14.0" -module-cache-path build/modules SnapForge/Advanced/*.swift SnapForge/Capture/CaptureService.swift SnapForge/Editing/*.swift SnapForge/ImageProcessing/*.swift SnapForge/Output/ImageOutput.swift SnapForge/Preferences/Preferences.swift Tests/PreviewLayout/main.swift -o build/tests/PreviewLayoutTests
build/tests/PreviewLayoutTests
