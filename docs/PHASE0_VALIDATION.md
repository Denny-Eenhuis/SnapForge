# Phase 0 validation — October 9, 2026

Environment: macOS 27.0.1 (26A434), Apple Silicon arm64; Swift 6.4; Command Line Tools MacOSX.sdk. Full Xcode is not installed in /Applications. `xcodebuild -version` and `-showsdks` failed because the active developer directory is CommandLineTools.

Created: native AppKit menu bar lifecycle, ScreenCaptureKit main-display capture service, permission denial guidance, preview with clipboard copy and PNG save, macOS 14 deployment target, shared Xcode scheme, universal Release build script, signing/deployment guidance, second-Mac checklist, ZIP and SHA-256.

Passed: optimized arm64 and x86_64 compilation; lipo confirmed both slices; staged ad-hoc signature verification; Info.plist and project plist syntax checks; transfer ZIP and checksum generation. Launch Services accepted `open` for the staged app (exit 0).

Initial failures: startup actor isolation compiler error fixed with main-actor startup; workspace file-provider Finder metadata blocked signing, fixed by signing in /private/tmp. Copied workspace bundle required removal of its generated FinderInfo metadata as well. No quarantine or security-policy attributes were removed.

Not verified: visible menu bar interaction, Screen Recording permission denial/grant, actual screenshot content, PNG/clipboard behavior, runtime on Intel, runtime on macOS 14, second-Mac installation. Process inspection via pgrep was unavailable in the execution environment. Launch acceptance does not prove sustained runtime or successful capture.

Xcode build and XCTest are blocked by missing full Xcode. No unit test target is included in the minimal phase; capture integration requires interactive macOS privacy approval. Do not call Phase 0 fully validated until Xcode build and the manual checklist pass. Later phases have not begun.
