# SnapForge

Independent, entirely local macOS menu bar screenshot utility. Capture, annotation editor and Phase 3 advanced tools; macOS 14+. See the validation reports for actual test coverage.

## Build

Open `SnapForge.xcodeproj` in full Xcode, select SnapForge and build. For an ad-hoc Release bundle:

```sh
xcodebuild -project SnapForge.xcodeproj -scheme SnapForge -configuration Release -derivedDataPath DerivedData CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=YES build
```

When only Apple's Command Line Tools are installed, run `./scripts/build.sh`. This compiles both architectures, creates and ad-hoc signs a Release app in a temporary local staging folder, prints its verified path, and creates `build/Release/SnapForge.zip` with a SHA-256 checksum. No third-party dependencies. This workspace’s file provider can invalidate runnable `.app` bundles with Finder metadata. The build therefore keeps the runnable app outside the project folder; use the ZIP and extract into a normal local folder. The staged app and ZIP extracted outside the synced workspace are signature-verified. Use the installed copy in your user Applications folder for capture permission validation.

Launch the app and click the camera in the menu bar. Capture the main display, choose any connected display, drag a region, or choose an application window. Grant Screen Recording permission when prompted. If required, quit and reopen after enabling permission in System Settings. The editor supports editable annotations, redaction, cropping, undo/redo, zoom/pan, Copy, Save and Save As using the PNG/JPEG format selected in Preferences. Capture uses ScreenCaptureKit's macOS 14 screenshot API at display pixel resolution. Region selection stays within one display. Preferences configure automatic copying, preview, automatic saving, output folder/format and global shortcuts.

## Architecture

- App: application lifecycle, menu commands, permission onboarding and errors.
- Capture: asynchronous ScreenCaptureKit screenshot service.
- Preview: manages an independent editor session per capture.
- Editing: pixel-coordinate annotation model, history, AppKit canvas and editor controls.
- ImageProcessing: Core Graphics compositing and Core Image blur/pixelation.
- Advanced: local Vision OCR, independent auxiliary windows, pixel inspection and scrolling overlap/stitching.
- Output: ImageIO PNG/JPEG export and clipboard.
- Preferences: SwiftUI controls and local UserDefaults persistence.
- Shortcuts: Carbon global hot-key registration, with conflict reporting.

Advanced tools add local Vision OCR, floating pins with opacity, source-pixel distance/ruler/color inspection, and region scrolling capture with overlap checks. See `docs/PHASE3_VALIDATION.md` for workflow and limitations. No network services or launch-at-login registration are included.

## Signing and deployment

An ad-hoc signature provides local code integrity, not a trusted developer identity. Without paid Apple Developer membership, you can build and copy an app for authorized testing, but cannot obtain Developer ID distribution signing or notarization. A free personal team in Xcode does not replace Developer ID signing for general distribution.

For ordinary distribution, use an approved paid Developer ID Application identity, hardened runtime, a timestamped signature, Apple notarization using `notarytool`, and stapling using `stapler`. Signing credentials and team configuration are intentionally absent from this repository. Notarization contacts Apple; screenshot processing remains entirely local. Consult Apple's current signing documentation and your organization's approved process before distribution.

On a second Mac, no Xcode is required. macOS may block an unnotarized or untrusted build, especially under managed-device policy. Use only OS-supported approval when permitted; otherwise obtain IT approval or a properly signed and notarized build. Do not remove quarantine, disable Gatekeeper or bypass management controls.

Run `./scripts/test.sh` for native automated checks. See `docs/SECOND_MAC_CHECKLIST.md`, `docs/PHASE0_VALIDATION.md` , `docs/PHASE1_VALIDATION.md` , `docs/PHASE2_VALIDATION.md` and `docs/PHASE3_VALIDATION.md` for actual validation and remaining manual checks.

Apple references: [Developer ID](https://developer.apple.com/developer-id/) and [macOS distribution](https://developer.apple.com/macos/distribution/).


## Development permission stability

The build script defaults to ad-hoc signing. Its designated requirement contains the binary's code-directory hash, which can change when code is rebuilt. An enabled Screen Recording entry may then refer to an earlier build. Freeze the installed binary during permission/capture validation; grant access to the final copy in your user Applications folder and quit/reopen that app through the supported macOS flow. Do not rebuild between the grant and the test.

For ongoing development, use an existing valid Apple Development signing identity rather than ad-hoc signing. The script accepts `SNAPFORGE_SIGNING_IDENTITY` as the identity name or certificate hash supplied to codesign. The certificate and its private key must already exist in the login keychain; this script does not create, import, or trust certificates. On October 9, 2026, this Mac reported zero valid code-signing identities. Developer ID remains the appropriate separately configured distribution route. Signing identity changes can require a fresh permission grant even when the app path remains stable.


Editor checks: `./scripts/test-editing.sh` uses native graphics access, and `./scripts/test-preview.sh` requires a graphical macOS session. `./scripts/build-editor-check.sh` creates a separate synthetic-image UI check app without capture permissions. Captured originals are immutable; annotations stay editable in their open window, and exports are flattened images.

Advanced checks: `./scripts/test-advanced.sh` requires native graphics access for Vision. Phase 3 tools process the edited/cropped output; scrolling capture is selected from the camera menu and starts automatic scrolling as soon as a region is selected, after the normal macOS Accessibility grant. Scroll movement is paced over 0.6 seconds with a 1.2-second pause between frames; Escape stops capture. Start above the bottom of the conversation and select the scrolling content.
