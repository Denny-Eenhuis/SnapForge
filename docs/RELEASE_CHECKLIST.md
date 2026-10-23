# Release readiness

## Local results

- Installed 0.5.1: original app icon, opt-in launch at login and revised Preferences layout. Prior capture, shortcuts, saving and continuous scrolling were confirmed by the user. Clipboard, OCR, pins and measurement have additional live verification on 0.5.1.
- The 0.5.1 ZIP and checksum match the installed release resources; universal architectures and strict signature verification pass.
- arm64 and x86_64 optimized binaries compile for macOS 14 or newer.
- ZIP extraction, strict ad-hoc signature verification and SHA-256 check pass.
- Configuration, exports, annotation history/rendering, synthetic shortcuts, editor layout, pins, local OCR and image overlap/seams have regression coverage.
- Candidate Preferences labels and help text inspected in light and dark appearance using a separate validation app. Launch-at-login remains off in that app; no login registration performed.

## Remaining before declaring production ready

- Stable Apple certificate signing; current ad-hoc signatures can invalidate privacy grants after code changes.
- Actual login registration, disable and next-login behavior, only with user consent.
- VoiceOver navigation/readout beyond exposed accessibility labels.
- Hardware multiple monitors; Retina/native dimensions currently have geometry tests and local capture confirmation.
- Intel runtime and authorized second Mac.
- Full Xcode build/test: unavailable on this Command Line Tools-only installation.
- Long-scroll and large-image memory profile. Advanced regression script including compiler measured about 253 MiB peak RSS; this is not whole-app peak usage under long scrolling.

## Transfer

Use `build/Release/SnapForge.zip` and `SnapForge.zip.sha256`. Verify the checksum, extract and install in Applications or a user-owned Applications directory. The receiving Mac needs macOS 14+, not Xcode. Follow [second-Mac checklist](SECOND_MAC_CHECKLIST.md). Follow normal security prompts and organizational approval; do not remove quarantine or weaken Gatekeeper.

A locally compiling, ad-hoc signed package does not establish notarization or corporate approval. Use a consistent approved signing identity for production updates. All login and privacy permission changes belong to the receiving user.

## Installed 0.5.0 follow-up

The user confirmed scrolling works after removing and re-adding both Screen Recording and Device Control/Accessibility permissions. Both prior grants failed following this ad-hoc update. Permission persistence is not verified and remains a signing blocker.

## Additional quality evidence

Installed 0.5.1 Command-C successfully opened the captured image in Preview via New from Clipboard. An optimized 24MP annotation/PNG/JPEG/crop test passed with 0.60 seconds wall time and about 493 MiB peak RSS. See [quality validation](PHASE5_VALIDATION.md); long-scroll and whole-app worst-case memory remain unmeasured.

Launch-at-login registration was observed enabled/allowed in macOS after user consent; actual next-login launch and disable testing remain pending.

The user confirmed SnapForge launched after a real logout/login. Launch-at-login startup is passed; disabling startup remains untested.

## Remaining-task audit

See [remaining checks](REMAINING_CHECKS.md): 40-frame all-pixel synthetic stitch stress and height protection passed; x86_64 configuration/export tests passed under Rosetta; disabling startup was observed in macOS and restored enabled. Strict integrity passes, but Gatekeeper distribution assessment rejects the ad-hoc app. Full Xcode, approved signing/notarization, physical Intel/second-Mac/multiple-monitor runtime and complete spoken VoiceOver testing remain open.

## Updated Xcode result

Full Xcode 27.0 is now installed and selected. Universal Debug and Release builds, signatures and icon resources passed, as did configuration/export, annotation and advanced regressions using its toolchain. The previous full-Xcode availability blocker is resolved. See [Xcode validation](XCODE_VALIDATION.md). The project has standalone executable test harnesses; it has no XCTest target and no xcodebuild test run is claimed.

The project now also includes an unhosted XCTest target and shared-scheme Test action. All six core XCTest cases passed through xcodebuild test on arm64, with zero failures/skips. The earlier absence of an XCTest target is resolved; see [Xcode validation](XCODE_VALIDATION.md).

## Second-Mac follow-up

The user confirmed successful operation on the workplace-managed second Mac on October 23, 2026. Basic second-Mac transfer/run testing is now user-confirmed. Hardware/OS details and per-feature results remain unrecorded, so physical Intel and multiple-monitor testing remain open. Stable signing/notarization is still unresolved.
