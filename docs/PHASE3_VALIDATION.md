# Phase 3 — October 9, 2026

## Implemented

- **Local OCR:** Recognize Text renders the current edited/cropped image, runs Apple's Vision accurate text recognition off the main thread, and opens selectable recognized text. Copy Selection and Copy All export text to the clipboard. No network client or external OCR service is used. Empty results and errors are explicit. Initial Vision model initialization can take noticeably longer than subsequent requests.
- **Pinned screenshots:** Pin Image opens a separate floating, movable, resizable, closable window with a 20–100% opacity slider. It uses the current edited output as a snapshot, independent of later edits. Auxiliary windows retain their images independently of the originating editor and release their owner on close.
- **Measurement:** Measure & Color opens a snapshot of edited output. Distance measures Euclidean length and x/y differences in source pixels; Pixel Ruler adds interval ticks; Color Picker reports a clicked pixel's sRGB HEX and RGB. Copy Value copies the result. Coordinates refer to the rendered/cropped output's top-left origin.
- **Scrolling capture:** The camera menu offers Scrolling Capture, then a window picker. Enter fixed header/footer exclusions in captured image pixels, capture the first frame, manually scroll downward by less than half the viewport, and add a frame. The session temporarily hides its controls during capture. Matching and compositing run off the main thread. Finish sends the resulting image through the normal clipboard/autosave/editor path.

Scrolling support is intentionally limited to stable vertical viewports. It does not send automated scroll events or request Accessibility access. Window dimensions and exclusions remain fixed during a session. At least 20% overlap is required. Unchanged frames, incompatible dimensions, unrelated/ambiguous frames and allocation failures are rejected without replacing the accepted composite. Animated content, sticky overlays, repeated rows, horizontal scrolling, zoom changes and asynchronous content loading may prevent a reliable result. Output is limited to 30,000 pixels high and 80 megapixels. No claim is made that every browser or application can stitch reliably.

## Verification

- Universal arm64/x86_64 optimized compilation and signed transfer packaging passed. The Xcode project includes all new sources and passed plist syntax validation. Full Xcode is absent; xcodebuild remains unverified.
- Advanced native tests passed real Vision recognition of rendered text, empty OCR, pixel color/orientation, HEX/RGB formatting, known overlap, three-frame dimensions and seam/source pixel preservation, and rejection of unchanged, dimension-changed and unrelated frames.
- A failed initial stitching fixture exposed both a coarse overlap search and reversed sampling coordinates; exhaustive pixel-shift matching and top-left pixel sampling fixed them. Regressions cover these cases.
- Vision cannot create its pixel buffers in the restricted command sandbox; the same executable passed with normal native graphics access. No privacy bypass was used.
- Editor layout/keyboard regression tests passed with the expanded toolbar, including at minimum window size. Native pin tests passed floating visibility, persistence on deactivation, resizable/closable styles and slider-driven alpha changes.
- In the separate synthetic editor app, live UI inspection confirmed recognized text matched both source labels, the selectable result and Copy All control opened, distance reported 399.4 pixels for the test drag, pixel ruler ticks were visible, and a blue bar reported HEX/RGB values. Clipboard contents from OCR were not independently checked.
- Capture, annotation/history/redaction and output/preferences regression tests passed.

## Pending runtime checks

The working installed Phase 2 app was preserved during development. The Phase 3 Release ZIP is built but not installed. Real browser/app scrolling sessions, error recovery after a target closes, actual screenshot OCR across languages, clipboard selection verification, large-image memory profiling, Intel runtime and second-Mac deployment need validation. Passing synthetic overlap tests do not establish browser integration success. This phase is implemented and partially verified, not declared fully complete.
