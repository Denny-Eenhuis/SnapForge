# Additional quality validation

## Installed app clipboard

On installed 0.5.1, the editor contained a saved 1484 × 142 capture with no annotations. Command-C in the editor followed by Preview's New from Clipboard created an Untitled image visibly matching that capture. This verifies editor command routing through real clipboard image encoding to another native app. The Preview copy is left open and unsaved. Automatic clipboard delivery is implemented and its preference is enabled, but this test explicitly exercised Command-C rather than observing a fresh automatic capture.

## Large-image export

`./scripts/test-large-images.sh` builds an optimized native test, then measures only the executable with `/usr/bin/time -l` (compilation excluded).

A synthetic 6000 × 4000 image (24 megapixels) was annotated with a rectangle, exported to PNG and JPEG, decoded at the original dimensions, and cropped to 4000 × 2000. Original source dimensions remained unchanged. All assertions passed.

Measured on the development Mac:

- 0.60 seconds wall time.
- 516,521,984 bytes maximum RSS (about 493 MiB).
- 504,464,440 bytes peak memory footprint.
- Zero swaps reported.

The simple synthetic fixture compresses well; these results do not establish photo-heavy export throughput, long-scroll memory behavior, or whole-app worst-case memory use. Source pixels, render buffers and decoded output intentionally coexist in this test. No installed binary was changed.

Remaining: stable signing/privacy persistence, actual opt-in login behavior, complete VoiceOver interaction, physical multiple monitors, Intel runtime, authorized second Mac and full Xcode build.

## Installed 0.5.1 advanced UI checks

- Recognize Text on the 1484 × 142 Finder capture completed and exposed expected words Applications, SnapForge and Downloads. Initial recognition was unusually slow: a short process sample showed Apple's TextRecognition/Espresso on-device compilation waiting on a system reply, while the app remained responsive. Recognition eventually finished during the other checks. Text cut off at the screenshot's lower edge produced OCR errors; this is not a claim of perfect recognition or reading order.
- Selected the recognized word SnapForge through the selectable text view and exercised Copy Selection. A separate destination paste for that text was not verified. Image clipboard was restored afterward with editor Command-C.
- Pin Image opened a floating window, the opacity slider changed from 1 to 0.5, and its close control returned to the editor. Resize/movement remained covered by prior native tests rather than repeated in this live check.
- Measure & Color opened successfully. A horizontal 300 screenshot-pixel drag across a 1752 screenshot-pixel display of the 1484 source-pixel image reported 254.1 source pixels, matching the displayed scale.
- Color Picker returned source coordinate (487, 59), HEX #464646 and RGB 70, 70, 70 for a gray selected-row background. Numerical source-color correctness remains covered by known-pixel unit fixtures.
- Pixel Ruler reported the same 254.1-pixel distance and visibly drew regular ticks along the line.
- Auxiliary validation windows were closed; the original saved image remains in the editor, ready to paste. No source edits, installed rebuild, privacy mutation or login registration occurred.
