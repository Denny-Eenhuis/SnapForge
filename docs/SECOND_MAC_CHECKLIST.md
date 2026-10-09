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
