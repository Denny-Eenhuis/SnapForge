# Phase 2 — October 9, 2026

## Implemented

The capture preview is now a native AppKit annotation editor. Each captured image owns an independent editor/document so new captures cannot replace unsaved edits.

- Arrows, rectangles, rounded rectangles, ellipses, lines, freehand pen, text and numbered callouts.
- Adjustable color, stroke width and text/callout size. Select a shape to edit its style, drag it to move, and drag endpoint handles to resize supported shapes. Double-click text to edit it.
- Blur and pixelation as editable rectangular effects. They process the current composited image in annotation order, including earlier annotations. Filter failures stop export rather than exporting an unredacted fallback.
- Non-destructive cropping, Reset Crop, undo and redo (up to 100 history steps). Crop coordinates remain in the original image's pixel space.
- Fit, zoom buttons, pinch zoom, scroll bars and Space-drag panning.
- Copy the flattened edited image, Save to the current destination, and Save As with the existing filename/folder. Automatic saving still saves the original capture before editing; edits are exported explicitly.
- Unsaved-edit prompts on window close and application quit. A saved state is tracked separately from current edits.
- Accessible tool labels, canvas image role/description, native buttons, color well and size pickers. Dark/light appearance uses system colors.

Annotations remain editable while their editor window is open. PNG/JPEG exports are flattened raster images; reopening an export does not restore its annotation objects. Persistent editable project files are not part of this phase.

## Keys

With the canvas focused: V Select, A Arrow, R Rectangle, U Rounded, E Ellipse, L Line, P Pen, T Text, N Number, B Blur, X Pixelate, C Crop. Delete removes the selected annotation; Escape cancels a draft/selection. Space-drag pans.

Command-Z/Shift-Command-Z undo/redo. Command-C copies edited output. Command-S saves, Shift-Command-S opens Save As. Command-0 fits; Command-plus/minus zoom. Global capture shortcuts retain the user's saved Preferences configuration.

## Verification

- Universal arm64/x86_64 optimized Release compilation passed; staged and extracted-ZIP signatures verified. Xcode project and Info.plist passed syntax checks. Full Xcode is still absent, so xcodebuild validation is pending.
- `scripts/test-editing.sh` passed annotation history, redo-branch invalidation, movement/identity, saved/dirty states, source immutability, crop dimensions and stroke alignment, invalid crop handling, blur/pixelation region behavior, orientation and actual colored pixels from every vector tool.
- Core Image rendering failed in the restricted command sandbox; rerunning the same tests with native graphics access passed. No renderer workaround or permission bypass was added.
- `scripts/test-preview.sh` passed large-image initial window sizing, toolbar containment, fitting after window resizing, original pixel dimensions and direct native Command-key routing.
- Existing output/configuration/geometry checks and Carbon dispatcher checks passed after the editor integration.
- A separate `com.snapforge.editor-check` app displayed a synthetic test image. Live UI inspection verified all tools and export controls, arrow and rectangle creation, undo/redo state changes and text entry. The user then reported "all functions work" during this editor check. This is user-observed verification; it does not establish every hardware/large-image edge case.

## Remaining

### Installed build validation follow-up

On October 9, the rendering/history/redaction tests, native editor sizing and keyboard-routing tests, and geometry/output/preferences tests were rerun successfully. The installed application's strict code-signature verification also passed. No installed binary was rebuilt or replaced during this follow-up.

The actual installed app displayed its Screen Recording permission-required alert during a capture attempt. The user independently confirmed the same error from the camera menu. Capture-to-editor and edited exports from a real capture therefore remain blocked by the current OS permission state; the passing synthetic tests do not establish those paths.

After the user renewed permission and captured from the camera menu, live inspection confirmed the installed editor opened a 3420 × 2214 capture. Arrow creation, Command-Z undo, Shift-Command-Z redo, blur and pixelation each updated annotation/history state. Cropping changed output dimensions to 1511 × 1008 while preserving three editable annotations. Save As exported `/private/tmp/SnapForge-validation-173138.jpeg`, returned the document to Saved, and retained editable annotations. `sips` confirmed JPEG format and 1511 × 1008 exported pixels. The original automatic save was not overwritten. The capture-to-editor and real edited-export blockers are resolved; no app rebuild was needed.

Validate the final installed app's capture-to-editor path after normal Screen Recording reauthorization if needed. Check annotation exports on actual Retina/multiple-monitor captures, larger memory workloads, detailed redaction strength and font/layout edge cases. Intel/macOS 14 runtime and second-Mac deployment remain pending. Persistent editor-project storage and advanced OCR/scrolling/pinning/measurement features are not implemented yet.

The verified previous capture app is backed up before replacement. No Gatekeeper/quarantine/privacy-policy bypass is used. Ad-hoc rebuilds can require a fresh OS Screen Recording grant; configure a valid stable signing identity for ongoing development.

The Phase 2 build was installed at `/Users/denny/Applications/SnapForge.app` after backing up the previous capture build to `/private/tmp/SnapForge-before-phase2.app`. Strict installed signature verification passed and process inspection confirmed the installed app is running. Initial UI inspection timed out because the newly launched menu bar app had no open capture window; capture-to-editor verification awaits the normal OS permission/relaunch flow if required. The synthetic check app is separate from the installed capture app.
