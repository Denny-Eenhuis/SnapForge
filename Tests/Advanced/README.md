# Advanced validation

`./scripts/test-advanced.sh` checks Vision OCR, pixel coordinates/colors, and deterministic scrolling composites. Vision needs normal native graphics access in this environment.

For live browser validation, use a local page with numbered, uniquely colored rows, no sticky headers, and enough content for at least three captures. Open SnapForge → Scrolling Capture, drag a region inside the browser content, excluding its toolbar and fixed page headers/footers. Keep the browser window size and zoom unchanged. The selection captures the first frame. Scroll less than half the selected region height, add two more frames, and finish in the editor. Confirm rows remain ordered and no rows repeat or disappear at seams. Add an unchanged frame to verify rejection preserves the previous composite.

Fixed headers or footers must be excluded. This is a manual scrolling workflow; synthetic tests alone do not verify browser support.

The browser-before/after PNG fixtures are screenshots of the local numbered test page, captured through the browser at scroll offsets 0 and 216. The suite checks that the production stitcher detects exactly 216 pixels of vertical displacement and exports the composite. These fixtures contain no user data. They test browser-rendered text and colored rows, but do not exercise the installed app’s OS event delivery.
