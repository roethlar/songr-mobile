# Machines

Machine-specific facts (local toolchains, host layout, per-clone posture),
keyed by machine and dated. See `.agents/state.md` write-time rules.

## michael-mac (darwin, primary)

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
