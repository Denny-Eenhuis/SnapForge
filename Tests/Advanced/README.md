# Advanced validation

`./scripts/test-advanced.sh` checks Vision OCR, pixel coordinates/colors, and deterministic scrolling composites. Vision needs normal native graphics access in this environment.

For live browser validation, use a local page with numbered, uniquely colored rows, no sticky headers, and enough content for at least three captures. Open SnapForge → Scrolling Capture, drag a region inside the browser content, excluding its toolbar and fixed page headers/footers. Keep the browser window size and zoom unchanged. The selection captures the first frame. Scroll less than half the selected region height, add two more frames, and finish in the editor. Confirm rows remain ordered and no rows repeat or disappear at seams. Add an unchanged frame to verify rejection preserves the previous composite.

Fixed headers or footers must be excluded. This is a manual scrolling workflow; synthetic tests alone do not verify browser support.
