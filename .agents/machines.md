# Machines

Machine-specific facts (local toolchains, host layout, per-clone posture),
keyed by machine and dated. See `.agents/state.md` write-time rules.

## michael-mac (darwin, primary)

- 2026-09-04: Simulator may reactivate its CarPlay window when a tool tries to tap the phone window. Close only the CarPlay window during phone input checks and reopen it afterward. Its accessibility tree can describe phone controls while the screenshot shows CarPlay; trust the actual target window. `-SongrForcePortrait` and `-SongrForceLandscape` set debug scene geometry; Simulator hardware rotation is separate.

- 2026-09-04, as of 4bea466: the protected simulator's existing CarPlay window
  was initially blank. Selecting Simulator > I/O > External Displays > CarPlay
  reconnected it successfully. The app then showed the existing library;
  artist/album screens and the native alphabet picker were inspected, including
  a jump to Z. No simulator erase, replacement, or keychain reset was used.

- 2026-09-04: Xcode 27 beta is also installed at `/Applications/Xcode-beta.app`
  and was used for the owner's physical iOS 27 device run. The owner confirmed
  Songr opens directly on the phone after Xcode reported a trust-related launch
  error. Read-only inspection confirmed Developer Mode is enabled and the
  installed development app is `com.draegloth.Songr`. Its matching, unexpired
  provisioning profile includes the phone and the CarPlay audio entitlement;
  actual in-car behavior has not been verified.
- 2026-09-04: the ignored `Songr.xcodeproj` now holds owner signing settings
  (team `27R2KCAHN7`, bundle identifier `com.roethlar.Songr`). These differ from
  tracked `project.yml` and the currently installed phone app. Do not regenerate
  that project over the owner's settings. For the touch-index verification,
  XcodeGen generated `build/touch-index-project/Songr.xcodeproj`, with App and
  Packages links pointing back into this repo; builds used the in-repo build
  directory. The original project's hash was unchanged.
- 2026-09-04: copied SwiftPM build caches still embed the former
  `/Users/michael/Dev/carplay_test` path. Fresh in-repo scratch output avoids
  that stale cache. CommandLineTools-only Swift could not import XCTest;
  using Xcode's toolchain via DEVELOPER_DIR and xcrun resolved it. The current
  verification command is in `.agents/repo-guidance.md`.

- 2026-09-04 (rechecked): `xcode-select` points at CommandLineTools;
  Xcode 26.6 is installed at `/Applications/Xcode.app` but is not active.
  Do not change system state — invoke builds with
  `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild …`
  (same for `xcrun`/`simctl`).
- 2026-09-04: sibling working copies `~/Dev/roon-controller` and
  `~/Dev/vela` exist as references. Architecture v3 has no runtime
  dependency on either working copy; see `.agents/decisions.md` for the
  read-only boundary.

- 2026-09-04, as of 2470fdf: this clone has a single-commit, non-shallow
  history. The historical implementation object `f7cd996` is absent;
  archived implementation ranges cannot be reconstructed from the
  reachable history. Their original verification claims were not rerun.

## HARD RULE (2026-08-31): sim 066A25C0-D9B1-4464-AEF2-2B4520F850CC must NEVER be erased/reset/deleted
`simctl erase` wipes the device keychain = destroys the owner's Plex link, forcing him to re-auth at plex.tv/link. This already happened once (erase at 13:38 during UI verification). Agents: install/launch only. Never `erase`, never delete the device, never create a replacement device for this app.
