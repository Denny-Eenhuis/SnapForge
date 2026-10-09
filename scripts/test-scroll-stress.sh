#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/tests build/modules
xcrun swiftc -O -sdk "$(xcrun --show-sdk-path)" -target "$(uname -m)-apple-macos14.0" -module-cache-path build/modules SnapForge/Advanced/*.swift SnapForge/Capture/CaptureService.swift SnapForge/Capture/RegionSelector.swift SnapForge/Capture/CaptureGeometry.swift Tests/ScrollStress/main.swift -o build/tests/ScrollStressTests
/usr/bin/time -l build/tests/ScrollStressTests
