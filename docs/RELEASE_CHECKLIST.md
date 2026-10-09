# Release readiness

## Local results

- Installed 0.4.7: capture, shortcuts, automatic saving and continuous region scrolling confirmed by the user.
- 0.5.0 candidate: adds opt-in launch at login and a revised Preferences layout; not installed over 0.4.7.
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
