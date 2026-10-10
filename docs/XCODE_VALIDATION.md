# Full Xcode validation

The user installed and configured Xcode. Active developer directory is `/Applications/Xcode.app/Contents/Developer`, Xcode 27.0 build 27A266a, with macOS 27 SDK and macOS 14 deployment target.

The project scheme resolves as SnapForge. Universal Release compilation initially passed without code signing. The project had a legacy headermap warning; explicitly setting ALWAYS_SEARCH_USER_PATHS=NO fixed it. A subsequent normal-cache Release build with the project's ad-hoc signing configuration exited successfully with an empty quiet log.

Release product verified:

- arm64 and x86_64 architectures.
- Strict signature integrity.
- Included AppIcon.icns matches the source resource.
- Minimum macOS version 14.0.

Configuration/Retina/export tests, annotation/history/redaction tests and Vision/scroll-stitching/browser-fixture regressions passed using Xcode's selected toolchain. These are the repository's standalone executable test harnesses; the project does not currently have an XCTest test target, and no xcodebuild test result is claimed.

The initial restricted invocation emitted simulator/cache-access warnings but still built successfully. Subsequent build validation used normal access and quiet logs. SnapForge does not require an iOS simulator.

Reproduce with `./scripts/test-xcode-build.sh`. Temporary products are in `/private/tmp`; the script does not install or launch them. No validation app replaced the permission-approved installed 0.5.1 app. Full Xcode availability/build is resolved; stable signing and notarization are separate and remain unresolved.

Debug also exited successfully with an empty quiet log; its strict signature, universal architectures and icon resource passed verification. Both products are in `/private/tmp/SnapForge-XcodeValidation/Build/Products`.
