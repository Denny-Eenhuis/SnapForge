#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/tests build/modules
xcrun swiftc -O -sdk "$(xcrun --show-sdk-path)" -target "$(uname -m)-apple-macos14.0" -module-cache-path build/modules SnapForge/Editing/Annotation.swift SnapForge/ImageProcessing/AnnotationRenderer.swift SnapForge/Output/ImageOutput.swift Tests/LargeImages/main.swift -o build/tests/LargeImageTests
/usr/bin/time -l build/tests/LargeImageTests
