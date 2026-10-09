# UX milestone — 0.5.0 candidate

The user confirmed the installed 0.4.7 continuous region scrolling capture works. That installed app remains unchanged to preserve its current privacy grants.

## Added

Preferences now offers opt-in Launch SnapForge at login using `SMAppService.mainApp`. Opening Preferences reads system registration status; it does not register anything. Only the user's toggle action registers or unregisters the login item. Pending approval exposes a Login Items Settings button, failures show an error, and status refreshes when the app becomes active. No LaunchAgent files or administrator operations are used.

## Verification

- Universal arm64/x86_64 optimized build passed with macOS 14 deployment target.
- Staged bundle and extracted ZIP strict signature checks passed (ad-hoc signing).
- Geometry, Retina scaling, PNG/JPEG round-trip, output errors and preference persistence passed.
- Annotation history, movement, saved state, crop alignment, redaction, vector rendering and immutable source pixels passed.
- Synthetic Carbon dispatcher delivery and cleanup passed; this does not substitute for physical shortcut testing.
- Native editor sizing, toolbar visibility, fit, editor keys, pins and initial scrolling frame delivery passed.
- `xcodebuild -version` failed because full Xcode is absent; no Xcode build is claimed.

## Pending

Login registration/disable and actual next-login launch require testing with user consent. The new Preferences layout, VoiceOver and light/dark appearance need visual checks. Multi-monitor hardware, Intel runtime, large-image memory profiling and second-Mac deployment remain outstanding. Stable certificate signing is not configured (zero valid identities on this Mac); ad-hoc replacement builds can require privacy reauthorization.

Candidate app: `/private/tmp/snapforge-build.tQqL8k/SnapForge.app`. Release ZIP/checksum are in `build/Release`. This candidate has not replaced the installed app.

A separate Preferences validation app exposed the original Form's clipped label/help layout. Replacing it with a leading-aligned vertical layout and wrapping help text fixed clipping; screenshots were inspected in both light and dark appearance. The accessibility tree exposed all expected checkbox, picker and button names, including disabled launch-at-login state. This does not establish complete VoiceOver usability. No login item was registered. The advanced regression suite passed again; `/usr/bin/time -l` around the script (including compilation) reported 264,830,976 bytes peak RSS and 8.70 seconds wall time.

After the layout fix, universal release compilation, extracted-package signature verification, configuration/export tests and the final ZIP checksum passed again. Installed 0.4.7 remains unchanged.
