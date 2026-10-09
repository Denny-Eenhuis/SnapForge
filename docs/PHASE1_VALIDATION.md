# Phase 1 — October 9, 2026

## Implemented

- Capture main display or any connected display from a dynamic menu.
- Drag a crosshair selection on frozen snapshots of connected screens. Escape cancels; each selection is limited to one display.
- Search/select an individual on-screen application window, excluding SnapForge's own windows, with ScreenCaptureKit's desktop-independent window filter.
- Display capture uses native pixel dimensions; region cropping uses actual screenshot-to-screen scale in each axis. Window capture uses the filter's point-to-pixel scale and excludes shadows.
- Global capture shortcuts with configurable modifiers and letter/number keys. Defaults: Command-Shift-1 main display, Command-Shift-2 region, Command-Shift-3 window. Apply Shortcuts reports duplicate keys and registration conflicts. Carbon hot keys require no Accessibility/Input Monitoring access. Key positions use a US keyboard map; alternate keyboard layouts need manual verification.
- Preferences persist locally in UserDefaults: automatic clipboard copy, preview visibility, PNG/JPEG format, automatic saving and user-selected folder.
- PNG clipboard output and PNG/JPEG save/export share ImageIO encoding. JPEG quality is 90%. Automatic filenames include timestamp and random suffix.
- If output fails or all output options are disabled, the preview opens so the image remains available to save.
- Screen Recording preflight/request, permission recovery guidance, display/window disappearance errors and file-write errors.

## Automated verification

`./scripts/test.sh` runs a standalone native Swift test executable with the available Command Line Tools. It checks Retina crop scaling, reversed drags, clipping, empty selections, different horizontal/vertical pixel scales, PNG exact pixel round-trip, JPEG pixel round-trip with lossy tolerance, pixel dimensions, saved bytes, nonexistent-folder failure and preference persistence in an isolated defaults suite.

Passed those checks. Initial export tests compared NSColor conversions across color spaces and failed; the final test compares decoded Core Graphics pixels in the source color space. Image export was moved to ImageIO to preserve the original CGImage profile.

Both arm64 and x86_64 Release compilation and universal/ad-hoc signature verification passed. The workspace file provider can reattach FinderInfo to the copied .app and invalidate signature verification; use the ZIP, verified after extraction into /private/tmp, for transfer and extract into a normal local folder. No quarantine attributes were removed. The Xcode project and Info.plist passed plist syntax checks. No full Xcode is installed, so xcodebuild/XCTest project execution remains unverified.

## Live verification pending after permission restart

Computer-use app inspection timed out. User reports permission granted and ChatGPT restart required for it to take effect. Actual screenshots, interactive controls, global hot-key registration, preview layout, clipboard pasting and window selection have not been verified in this session. Build success is not a claim of completed runtime validation.

After restarting ChatGPT, quit any older SnapForge instance before launching the updated bundle, then:

1. Open the app and Preferences. Verify all controls are visible and their settings survive relaunch.
2. Capture Main Display, paste into Preview and compare pixel dimensions with display resolution.
3. Capture each connected display; test different Retina scales and displays above/below or left/right of the main display.
4. Select a region on each screen in both drag directions and at all four edges. Verify crop contents/orientation, Escape cancellation and a second selection after cancellation. Crossing displays clamps to the starting screen.
5. Select a window from another app. Verify content and scale; close a window during selection and verify a handled error.
6. Test default shortcuts with another app focused. Configure unique keys/modifiers and apply. Check duplicate keys and an occupied combination report errors.
7. Test PNG/JPEG saves, automatic saving, a deleted/unwritable folder, clipboard-only capture, preview-only capture and all outputs off.
8. Test permission denial/recovery through the OS, relaunching when required. Do not alter privacy/security settings through undocumented workarounds.
9. Test Intel/macOS 14 and a second authorized Mac using the deployment checklist.

Limitations: one display per region, sequential frozen display snapshots, on-screen shareable windows only, fixed JPEG quality, US physical key map, no annotation editor/OCR/scrolling capture yet.

## Resumed live validation — October 9, 2026

After the permission restart, computer-use inventory and Finder accessibility inspection responded. SnapForge inspection by the exact current app path continued to return timeoutReached. Bundle-ID lookup reported multiple registered build paths.

Process inspection outside the sandbox identified three running SnapForge builds (Phase 0, an intermediate Phase 1 build and the current build). With user-approved process termination, those test processes were closed. Relaunching the current staged build left exactly one process, `/private/tmp/snapforge-build.9SdcaY/SnapForge.app/Contents/MacOS/SnapForge`, confirmed by pgrep. Its staged signature passed strict verification. SnapForge UI inspection still timed out, so the older instances were not the sole cause.

A window-capture hot-key attempt from Finder did not yield an inspectable SnapForge window. This is inconclusive and does not count as a passed shortcut/capture test. The user was asked to confirm the menu bar icon and open Preferences so inspection can resume against a visible window. No Screen Recording privacy settings were changed during this resumed check. Interactive capture, save, clipboard and shortcut validation remains pending.

### Preferences window and duplicate-instance follow-up

The user supplied a screenshot of the open Preferences window. Computer-use inspection then succeeded and exposed all controls and labels. Clipboard copying and preview were enabled, PNG was selected, automatic saving was off, and global shortcuts were enabled with Command-Shift and keys 1/2/3. Applying shortcuts did not show an error. Automated Command-Shift-1 attempts did not expose a preview or permission dialog, so shortcut/capture behavior is still inconclusive.

The user reported two camera icons. Process inspection confirmed a staged app and the workspace app were running together. The duplicate workspace process was closed with user-approved termination; the staged instance and its Preferences window remained inspectable. A source fix now exits a newly launched copy when another app with the same bundle identifier is running, and reopening SnapForge opens Preferences. The lifecycle changes compile with the universal build; A launch attempt of the updated staged copy while the earlier staged instance was running left exactly one SnapForge process, confirming the new copy exited. Reopen behavior remains pending. The user was asked to run Capture Main Display directly from the remaining menu to distinguish capture failure from shortcut delivery.
