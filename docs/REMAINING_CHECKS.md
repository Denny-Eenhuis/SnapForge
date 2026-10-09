# Remaining-task audit — installed 0.5.1

## Passed locally

- Installed strict code-signature integrity.
- ZIP SHA-256 integrity and universal arm64/x86_64 architecture.
- Forty sequential synthetic scrolling frames, 1024 × 900 viewport and 240-pixel shifts, yielding 1024 × 10,260. Every output byte matched the original fixture, covering all seams.
- 30,000-pixel height guard rejected a further append before allocating a composite.
- Optimized scroll stress executable: 0.82 seconds wall time, 309,624,832 bytes peak RSS (about 295 MiB), zero swaps. Compilation excluded. This measures the stitching engine, not continuous capture of a live application or worst-case 80MP memory.
- x86_64 geometry, Retina scaling, PNG/JPEG encoding, output-error and preference tests executed under existing Rosetta and passed. This provides translated Intel-code evidence, not physical Intel hardware or Intel capture/Vision verification.
- Launch-at-login toggle off produced checkbox 0 with no error. Read-only macOS background-item state showed disabled, allowed, notified. Re-enabled afterward, checkbox 1; a subsequent read-only OS query confirmed enabled, allowed, notified again. A real logout/login while disabled was not performed; earlier user report verifies launch while enabled.
- Preferences accessibility tree exposes named toggles, popups and buttons. Earlier editor/OCR/pin/measurement trees expose their controls and canvas descriptions.

## Unavailable or unresolved

- Stable signing: zero valid code-signing identities. Installed designated requirement is build-hash based. Both grants were previously reported lost across an ad-hoc update. No signing fix or permission persistence claim.
- Distribution assessment: `spctl --assess --type execute --verbose=2` rejected the installed app (exit 3). Strict signature integrity does not establish Gatekeeper acceptance/notarization. No bypass or security setting change attempted.
- Full Xcode: `xcodebuild -version` failed because active developer directory is Command Line Tools. No full Xcode build claimed.
- Physical Intel and second-Mac test: no connected execution environment for that Mac. Rosetta results are distinguished above.
- Multiple-monitor hardware capture: physical monitor results unavailable; prior geometry tests cover pixel scaling and coordinate conversion only.
- Complete VoiceOver interaction/spoken output: accessibility labels inspected, but not a complete auditory/navigation test. Current VoiceOver state was not available from the queried preference key; user accessibility settings were left unchanged. A user-assisted VoiceOver check remains necessary.
- Long live scroll capture with loading/animation and near-limit memory remains pending despite exact 40-frame synthetic engine test.

The installed binary, privacy grants and output preferences were unchanged throughout. Startup was restored enabled after its temporary disable test.
