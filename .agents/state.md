# Agent State

This file is the first place future agents should read for current repo state.
Keep it short: `## Now` holds only live entries; the `catchup` hygiene
sweep rotates landed or superseded entries verbatim to
`docs/history/state-archive.md` (create it on first use) — never summarize
them away, never let them pile up here. `handoff` is the fast snapshot and
rotates nothing. Write-time rules: volatile facts
(CI state, counts) carry `as of <commit>`; push status is never recorded
here — git owns it, and unpushed work is mentioned in the moment it
matters, never written down; a count or enumeration another file owns is
pointed to, never copied; machine-specific facts (local toolchains, host layout, per-clone posture) go to the tracked
`.agents/machines.md`, keyed by machine and dated — never here.

## Now

- Browse rejections fixed (2026-08-31, commits f7cd996..HEAD, owner
  absent): (1) A–Z rail: SUPERSEDED same day by owner ruling "no scrub bar,
  simple clickable letters" — rail is now plain tappable letter cells
  (full cell-width targets, ≥24pt; portrait one column, compact-height
  landscape two), no bubble, no scrub, no kth-letter thinning. (2) Landscape artists list is
  multi-column (width-driven 1/2/3, letter groups flow CSS-columns
  order, lazy). (3) New browse scopes in web build-v5 chip order:
  Genres (card grid + rail → genre album grid), Playlists (rows →
  playlist tracks with artist credits, play-from-track), Recently
  played / Most played / Recently added (album shelves, server order).
  SongrKit fetchers + 7 stub tests; shelves live in AppModel, refresh
  on chip re-select, unlink on 401. Verified
  against the owner's real library on sim 066A25C0 (screenshots:
  `.agents/screenshots/*-portrait.png` / `*-landscape*.png`); every
  Plex endpoint behaved as documented — genre ids filter
  `all?type=9&genre=`, `/playlists?playlistType=audio` + `/items`
  (order and grandparentTitle intact), `viewCount>>=0` accepted for
  the played shelves. 63/63 `swift test` green as of this entry.
  DEBUG screenshot args: -SongrPreviewScope <raw>/-SongrPreviewGenre/
  -SongrPreviewPlaylist/-SongrPreviewScrub work against the real
  library (no preview harness needed).
- Found broken at baseline 12d2c4a: that commit's CarPlay
  condensed/grid CPListImageRowItem code is iOS 26-only, so the app
  did not compile at deployment target 17. Fixed in f7cd996 with
  availability guards + the pre-26 fallbacks restored from c0f2c5c
  (plain indexed artist rows, batched cover rows). Sim (iPhone 17 Pro,
  iOS 26.0) exercises the 26 paths; the fallbacks are build-verified
  only.
- Architecture v3 LANDED (2026-08-31, commits a84fe5c + 00694f2): this
  repo is now the whole product — standalone native player, phone talks
  straight to Plex. All v2 songr-server client code (WKWebView shell,
  endpoint socket client, SongrAPI, ServerConfig) deleted; v2 state
  entries rotated to `docs/history/state-archive.md`.
- `Packages/SongrKit` (local SwiftPM, platform-neutral): `LibrarySource`
  protocol seam (Plex now, Jellyfin later), Plex PIN OAuth + once-minted
  client identifier, vela-order server discovery (https-only,
  plex.direct/local first, relay last, /identity machine probe), paged
  music browse, artwork transcode + direct-play requests (auth in
  headers, never URLs), CatalogStore disk cache with A–Z/# sectioning +
  recomputed album counts, PlaybackQueue rules, CarPlayBrowsePlan
  (index titles, image-row batching). 43/43 tests green via
  `swift test` on macOS as of 00694f2 — no simulator, no network
  (URLProtocol stubs + authored fixtures).
- App target: SwiftUI phone UI per Browse UX directive (one continuous
  artists list "name — N albums" with touch-draggable A–Z/# rail, album
  artwork grid, album detail plays from tapped track, mini bar + full
  now-playing sheet, portrait+landscape via adaptive layouts);
  PlayerEngine (AVQueuePlayer, background audio, MPNowPlayingInfoCenter
  + remote commands); CarPlay CPTabBarTemplate Artists / Albums / Now
  Playing (sectionIndexTitle rail, CPListImageRowItem cover rows with
  lazy `update()` artwork, cover → track list → play-from-track).
  `xcodebuild build` (iOS Simulator, generic destination,
  `-derivedDataPath ./build`) zero errors / zero warnings as of 00694f2.
- Known soft spots to revisit once on-screen verification is allowed:
  Albums-tab artwork loads sequentially in the background (4k covers
  fill over time; visible rows come first); CarPlay artists list clamps
  to CPListTemplate.maximumItemCount (head-unit platform cap).
- Plex credentials now live in the Keychain (LANDED 2026-08-31, commits
  e9507b5 + e3121a4): `KeychainCredentialStore` in SongrKit
  (kSecClassGenericPassword, service `com.draegloth.Songr.plex`,
  accounts = the old `plex.*` keys; AfterFirstUnlock, never
  Synchronizable). Reinstalls/rebuilds keep the link — the reinstall
  token loss cannot recur. One-time migration imports whatever
  UserDefaults still held, then deletes the plaintext copies; on the
  owner's sim that was only `plex.clientIdentifier`
  (E926A4F6-3CA1-4544-AE9F-891C6236A578), verified moved (defaults
  domain now empty) after a no-args launch on sim 066A25C0. Decisions
  taken owner-absent (owner unavailable this session): accessibility is
  AfterFirstUnlock *without* ThisDeviceOnly so an encrypted backup
  restore to a new phone keeps the link; migration is gated on an
  entirely-empty keychain and never overwrites keychain truth. SecItem
  sits behind a `KeychainItemStoring` seam; tests use a dictionary
  fake, so `swift test` stays macOS-clean. 56/56 tests green as of
  e9507b5.
- Now-playing preview screenshot bug (showed "Gold Dust Woman" instead
  of startAt: 2 "Never Going Back Again") fixed in 9987db8. Corrected
  diagnosis, recorded because the fix request misattributed it: the
  rumoursTracks fixture order already matches fetchTracks' (disc,
  track) sort — the real cause was preview streams from /dev/null,
  whose failed AVPlayerItems AVQueuePlayer drops even while paused,
  parking the queue on the album's last track. Preview streamRequest
  now throws (like artwork), so the queue keeps its start index. Not
  re-screenshotted this session (launching with preview args was out
  of bounds).
- Settings → "Music Library" library switcher confirmed present and
  reachable (RootView Settings bar button → SettingsView cards →
  AppModel.selectLibrary); nothing added.
- Uncommitted WIP not from this work (as of 9987db8): ArtistsView /
  RootView jump-rail + navigation edits from a prior session sit
  unstaged in the working tree; left untouched, ownership unclear.

## Next

- Owner: approve booting the iOS Simulator so the phone UI (portrait +
  landscape) and CarPlay templates can be verified on screen — the
  repo boundary forbade install/boot/launch this session, so v3 UI is
  build- and unit-test-verified only.
- Owner: sign in once more on the sim (app installed, left on the real
  link screen) — this link now lands in the Keychain and survives
  reinstalls; nothing an agent can do headlessly.
- After first link: sanity-check catalog scale (~2000 artists / ~4000
  albums) on device — paging, cache write, jump-rail feel.

## Blockers

- CarPlay audio entitlement requested from Apple; approval pending
  (as of setup, 2026-08-30). Blocks real-car testing only.
- Device signing not yet configured (owner to set; simulator ad-hoc
  signing embeds the CarPlay entitlement meanwhile).

## Verification

- See `.agents/repo-guidance.md` (Verification) — the canonical home for the
  verification command. Deviation active now (v3): unit tests run with
  `cd Packages/SongrKit && swift test` (macOS, no simulator); app builds
  with `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
  xcodebuild -project Songr.xcodeproj -scheme Songr -destination
  'generic/platform=iOS Simulator' -derivedDataPath ./build build`
  (regenerate the ignored project with `xcodegen generate` first).
  `xcodebuild test` is deliberately not used — it would boot a
  simulator device (repo boundary).

## Active Sources

- `AGENTS.md`
- `.agents/repo-guidance.md`
- `.agents/decisions.md`

## Unrecorded Repo Memory

- None known.

## HARD RULE (2026-08-31): sim 066A25C0-D9B1-4464-AEF2-2B4520F850CC must NEVER be erased/reset/deleted
`simctl erase` wipes the device keychain = destroys the owner's Plex link, forcing him to re-auth at plex.tv/link. This already happened once (erase at 13:38 during UI verification). Agents: install/launch only. Never `erase`, never delete the device, never create a replacement device for this app.
