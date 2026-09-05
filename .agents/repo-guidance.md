# Repo-Specific Guidance
<!-- Extends AGENTS.md; never overrides it. Rules and pointers only — state
     lives in .agents/state.md. -->

## Mission Detail

A personal iOS + CarPlay music player for the owner's own music library — a
no-subscription alternative to Roon Arc / Plexamp. Personal use only; never
intended for App Store publication (runs via the owner's Apple developer
account). Owner: Michael.

## Reading Order

1. `AGENTS.md`
2. `.agents/repo-guidance.md` (this file)
3. `.agents/state.md`
4. `.agents/decisions.md`

## Verification

- Unit tests (macOS, no simulator): from the repo root, run
  `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test --package-path Packages/SongrKit --scratch-path build/songrkit-tests`.
  This uses Xcode's XCTest support and an in-repo compiler cache; see
  `.agents/machines.md` for the toolchain and copied-cache diagnosis.
- App build: run `xcodegen generate` at the repo root, then
  `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild
  -project Songr.xcodeproj -scheme Songr -destination
  'generic/platform=iOS Simulator' -derivedDataPath ./build build`.
  Toolchain location and simulator protection live in `.agents/machines.md`.
- For simulator verification, follow the standing exception in
  `.agents/decisions.md` and the protected-device rule in
  `.agents/machines.md`. The build command above does not boot a device.

- Before regenerating the project, check `.agents/machines.md` for owner
  signing overrides. When they exist, use a separate verification project
  so regeneration does not overwrite the working device configuration.

## Remotes & Sync

Remotes are configured in git; inspect them with `git remote -v`.
Push policy: `.agents/push-policy.md`.

## Earned Practices

None yet.
