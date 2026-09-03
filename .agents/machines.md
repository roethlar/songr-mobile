# Machines

Machine-specific facts (local toolchains, host layout, per-clone posture),
keyed by machine and dated. See `.agents/state.md` write-time rules.

## michael-mac (darwin, primary)

- 2026-08-30: `xcode-select` points at CommandLineTools; Xcode 26.6 is
  installed at `/Applications/Xcode.app` but NOT active. Do not change
  system state — invoke builds with
  `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild …`
  (same for `xcrun`/`simctl`).
- 2026-08-30: sibling working copies this project depends on:
  `~/Dev/roon-controller` (songr, Node+SvelteKit, branch `main`),
  `~/Dev/vela` (Tauri/Svelte media client — reference for Plex/Jellyfin
  API client patterns).
