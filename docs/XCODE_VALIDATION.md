# Full Xcode validation

The user installed and configured Xcode. Active developer directory is `/Applications/Xcode.app/Contents/Developer`, Xcode 27.0 build 27A266a, with macOS 27 SDK and macOS 14 deployment target.

The project scheme resolves as SnapForge. Universal Release compilation initially passed without code signing. The project had a legacy headermap warning; explicitly setting ALWAYS_SEARCH_USER_PATHS=NO fixed it. A subsequent normal-cache Release build with the project's ad-hoc signing configuration exited successfully with an empty quiet log.

Release product verified:

- arm64 and x86_64 architectures.
- Strict signature integrity.
- Included AppIcon.icns matches the source resource.
- Minimum macOS version 14.0.

Configuration/Retina/export tests, annotation/history/redaction tests and Vision/scroll-stitching/browser-fixture regressions passed using Xcode's selected toolchain. Those initial runs used the repository's standalone executable harnesses. A subsequent unhosted XCTest target was added and verified below.

The initial restricted invocation emitted simulator/cache-access warnings but still built successfully. Subsequent build validation used normal access and quiet logs. SnapForge does not require an iOS simulator.

Reproduce with `./scripts/test-xcode-build.sh`. Temporary products are in `/private/tmp`; the script does not install or launch them. No validation app replaced the permission-approved installed 0.5.1 app. Full Xcode availability/build is resolved; stable signing and notarization are separate and remain unresolved.

Debug also exited successfully with an empty quiet log; its strict signature, universal architectures and icon resource passed verification. Both products are in `/private/tmp/SnapForge-XcodeValidation/Build/Products`.

## XCTest integration

The shared SnapForge scheme now includes SnapForgeTests, an unhosted macOS logic-test target. It compiles the production geometry, output, preference, annotation and rendering modules directly; it does not launch the installed app or a test-host SnapForge process.

`xcodebuild test` on arm64 passed all six cases with zero failures, zero skips and no test runtime warnings:

- Retina crop, reversed drag and empty-selection rejection.
- PNG/JPEG dimensions and sRGB pixel preservation.
- Missing-folder save rejection and autosave filename reuse.
- Isolated preference defaults and persistence.
- Undo/redo, saved state and redo-branch invalidation.
- Crop output dimensions, out-of-bounds rejection and original preservation.

Initial color assertions through NSBitmapImageRep/NSColor failed in the test runner. An explicit sRGB fixture alone did not resolve that conversion discrepancy. Direct decoded sRGB bitmap-channel assertions passed, with exact PNG channels and JPEG tolerance of three channel units; no application encoder changes were made.

Final result: `/private/tmp/SnapForge-CoreTests-pixels.xcresult`. Reproduce using `./scripts/test-xcode.sh` or Product → Test (Command-U). Xcode emitted an internal test-launch completion-handler diagnostic, but the result bundle reported Passed with no test runtime warnings. Earlier standalone image-processing, OCR, scrolling and native UI suites remain complementary coverage. The installed app and privacy permissions were unchanged.
