# SnapForge

Independent, entirely local macOS menu bar screenshot utility. Phase 0 only; macOS 14+.

## Build

Open `SnapForge.xcodeproj` in full Xcode, select SnapForge and build. For an ad-hoc Release bundle:

```sh
xcodebuild -project SnapForge.xcodeproj -scheme SnapForge -configuration Release -derivedDataPath DerivedData CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=YES build
```

When only Apple's Command Line Tools are installed, run `./scripts/build.sh`. This compiles both architectures, creates and ad-hoc signs `build/Release/SnapForge.app`, verifies its signature, and creates a transfer ZIP and SHA-256 checksum. No third-party dependencies.

Launch the app and click the camera in the menu bar → Capture Main Display. Grant Screen Recording permission when prompted. If required, quit and reopen after enabling permission in System Settings. The preview supports Copy and Save PNG. Capture uses ScreenCaptureKit's macOS 14 screenshot API at display pixel resolution. The app captures the main display only in this phase.

## Architecture

- App: application lifecycle, menu commands, permission onboarding and errors.
- Capture: asynchronous ScreenCaptureKit screenshot service.
- Preview: AppKit image window, PNG export and clipboard.

Future phases can add independent editing, image processing, OCR and preferences modules. No network services, launch-at-login registration or global shortcuts are included.

## Signing and deployment

An ad-hoc signature provides local code integrity, not a trusted developer identity. Without paid Apple Developer membership, you can build and copy an app for authorized testing, but cannot obtain Developer ID distribution signing or notarization. A free personal team in Xcode does not replace Developer ID signing for general distribution.

For ordinary distribution, use an approved paid Developer ID Application identity, hardened runtime, a timestamped signature, Apple notarization using `notarytool`, and stapling using `stapler`. Signing credentials and team configuration are intentionally absent from this repository. Notarization contacts Apple; screenshot processing remains entirely local. Consult Apple's current signing documentation and your organization's approved process before distribution.

On a second Mac, no Xcode is required. macOS may block an unnotarized or untrusted build, especially under managed-device policy. Use only OS-supported approval when permitted; otherwise obtain IT approval or a properly signed and notarized build. Do not remove quarantine, disable Gatekeeper or bypass management controls.

See `docs/SECOND_MAC_CHECKLIST.md` and `docs/PHASE0_VALIDATION.md`.

Apple references: [Developer ID](https://developer.apple.com/developer-id/) and [macOS distribution](https://developer.apple.com/macos/distribution/).
