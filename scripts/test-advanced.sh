#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/tests build/modules
xcrun swiftc -sdk "$(xcrun --show-sdk-path)" -target "$(uname -m)-apple-macos14.0" -module-cache-path build/modules SnapForge/Advanced/*.swift SnapForge/Capture/CaptureService.swift Tests/Advanced/main.swift -o build/tests/AdvancedTests
build/tests/AdvancedTests
