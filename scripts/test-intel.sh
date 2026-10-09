#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
/usr/bin/arch -x86_64 /usr/bin/true
mkdir -p build/tests build/modules
xcrun swiftc -O -sdk "$(xcrun --show-sdk-path)" -target x86_64-apple-macos14.0 -module-cache-path build/modules SnapForge/Capture/CaptureGeometry.swift SnapForge/Output/ImageOutput.swift SnapForge/Preferences/Preferences.swift Tests/main.swift -o build/tests/SnapForgeTests-x86_64
/usr/bin/arch -x86_64 build/tests/SnapForgeTests-x86_64
