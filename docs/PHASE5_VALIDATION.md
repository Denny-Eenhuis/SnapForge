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
