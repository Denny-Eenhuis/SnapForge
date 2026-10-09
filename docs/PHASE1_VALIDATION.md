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
