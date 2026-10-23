# Authorized second-Mac test

- Confirm macOS 14 or newer and arm64 or Intel hardware.
- Obtain organizational approval where required; choose an approved signing/distribution route.
- Transfer SnapForge.zip and its checksum through an approved channel.
- Run `shasum -a 256 SnapForge.zip` and compare with the supplied checksum.
- Extract and copy SnapForge.app to Applications or a user-owned Applications folder.
- Open using the organization's approved macOS security workflow. If blocked by policy, stop and consult IT.
- Confirm the camera icon appears in the menu bar.
- Choose Capture Main Display. Check permission denial produces an actionable message.
- Grant Screen Recording permission through System Settings, then quit and reopen if required.
- Capture again; verify the preview matches the main display and Retina pixel dimensions.
- Copy and paste into Preview; save PNG, reopen it and inspect image quality.
- Test a second capture, preview resizing, closing/reopening and Quit.
- Repeat on Intel if available. Report actual hardware, OS, signing method and results.

No Xcode or administrator access is required for normal operation; corporate policy can impose additional restrictions.

## Full-feature verification

- Verify region and window capture, physical configured shortcuts and cancellation.
- Test automatic save followed by Save As; verify the same suggested filename is reused.
- Annotate, undo/redo, crop, copy and export both formats; inspect redaction and dimensions.
- Start scrolling above the bottom of a conversation, select its scrolling area, and check several stitched seams. Grant Device Control/Accessibility only through the normal settings flow. Verify Escape stops and opens the result.
- Recognize a known text image, select/copy part and copy all; confirm local output.
- Pin an image, adjust opacity, resize, move and close. Check ruler/distance/color readings on known source pixels.
- Inspect Preferences in light/dark mode and navigate controls with VoiceOver.
- If the user opts in, enable Launch at login, check any required system approval, log out/in and verify one running instance. Disable it and verify the next login does not launch the app.
- Record hardware, OS, signing identity, permissions and pass/fail evidence.

## User-reported second-Mac result

On October 23, 2026, the user confirmed SnapForge works on the second computer after receiving the transfer/opening and permission setup instructions. The second Mac is workplace-managed. This verifies user-reported second-Mac operation; the model, architecture, macOS version, monitor setup and individual feature results were not supplied. Do not infer physical Intel, multiple-monitor coverage, every checklist item, or Gatekeeper approval without a per-app exception from this report.
