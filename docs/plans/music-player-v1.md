# Plan: personal remote music player (songr core + iOS/CarPlay shell) — v2

Status: ACTIVE — owner directive 2026-08-30: full delegation, direction
fixed (Plex/Jellyfin backend support, songr interface, iOS & CarPlay app).
v2 supersedes v1's standalone-native-app architecture in place; Decision 1
is closed by the architecture decision in `.agents/decisions.md`
(2026-08-30).

## Problem

Owner streams a personal music collection (~2000 artists, ~4000 albums)
from home to an iPhone, primarily in the car. Existing apps fail him:
Roon Arc (no A–Z jump lists — unsafe scroll-while-driving; no track-level
play; large library gaps), Plexamp (his Plex mixes podcasts/audiobooks/
music; car/house context switching is painful). He already built songr
(`~/Dev/roon-controller`), a web controller whose UI solves the browse
problems (jump lists, palette search, track-level quick-play) but which
routes playback to Roon zones — it plays no audio itself. Personal use
only; never App Store-published.

## Architecture (v2)

Two codebases, one system:

1. **songr** (`~/Dev/roon-controller` repo) becomes the core:
   - `LibrarySource` plugin interface; Plex and Jellyfin sources added
     alongside Roon (Roon keeps browsing Roon and playing to Roon zones —
     home behavior unchanged).
   - Per-zone queue manager for **endpoint zones**: a phone registers over
     the existing Socket.IO layer as a zone ("iPhone"); the server sends it
     stream URLs + queue advance commands; the endpoint reports state.
   - The Svelte UI is unchanged (or minimally changed): new zones simply
     appear; browse/queue/transport contracts stay as-is.
   - Control plane = sockets; data plane = HTTP audio direct from
     Plex/Jellyfin to the endpoint. songr never touches audio bytes.
2. **iOS app** (this repo) is a thin shell:
   - WKWebView loading songr's UI (phone face — exact songr UI).
   - Native endpoint client: Socket.IO zone registration + `AVQueuePlayer`
     streaming token'd URLs; background-audio; `MPNowPlayingInfoCenter` /
     `MPRemoteCommandCenter`; interruption & route-change handling.
   - CarPlay (`CPTemplateApplicationScene`, audio entitlement): native
     templates only (Apple mandate) — tab bar: Artists / Albums / Recently
     Added / Now Playing; A–Z letter drill-down; track-level play. Fed from
     songr's existing browse HTTP/socket API.

Seam design doc (contract inventory, Roon-leak analysis, phased touch
list): `docs/design/songr-source-seam.md` — in progress, authoritative for
implementation order once landed.

## Hard requirements (unchanged from v1, restated against v2)

1. A–Z jump navigation in Artists/Albums on phone (songr UI already has
   it) AND on CarPlay (letter drill-down; every list reachable in ≤2 taps).
2. Track-level play everywhere; whole-album/queue-from-here only on
   explicit choice.
3. Completeness: in-app counts vs. source-server counts surfaced and
   matching (per source). Plex music section / Jellyfin music library
   counts checked before UI work (S2).
4. Music only: sources pin the music library section; podcasts/audiobooks
   never enter the catalog.
5. Remote over owner's existing WireGuard; endpoints stream direct from
   source servers over it.

## Milestones

songr repo (branch off main; Roon regression suite must stay green):

- **S1** — Endpoint zone + queue manager, sources off: phone-endpoint
  socket protocol (register / play(url,meta) / pause / resume / seek /
  state,position,stall reporting / reconnect), zone appears in UI zone
  list. Roon-only behavior provably unchanged.
- **S2** — `LibrarySource` interface + Plex source: token auth, music
  section pinned, catalog sync into existing store, search, stream +
  artwork URLs (artwork proxied — tokens never reach the browser), counts
  check vs. server.
- **S3** — Jellyfin source (same interface; proves the plugin seam).

iOS repo (this repo):

- **P1** — Scaffold: Xcode project (via `DEVELOPER_DIR` override, see
  `.agents/machines.md`), WKWebView shell against home songr, native
  endpoint client + `AVQueuePlayer`, background audio, lock-screen
  controls. Verified in iOS Simulator against live songr.
- **P2** — CarPlay: scene, tab-bar + letter drill-down templates,
  now-playing template. Verified in Xcode CarPlay simulator (entitlement
  not required there).
- **P3** — Hardening: reconnect/stall handling in car conditions,
  transcode-bitrate fallback, artwork caching; on-device via owner's
  signing team; real-car once Apple approves the CarPlay entitlement.

## Needs from owner (live blockers mirrored in `.agents/state.md`)

- Plex server URL + `X-Plex-Token`, Jellyfin server URL + API key —
  dropped into `~/Dev/roon-controller/.env.local` (owner-created,
  git-ignored). Needed at S2/S3 start.
- Xcode signing team selection when P3 goes on-device.
- CarPlay entitlement approval (pending with Apple) — blocks real-car
  only.

## Non-goals (v1 scope)

- No offline downloads (endpoint-cache design is a v2 candidate).
- No podcasts/audiobooks/video, no multi-user, no Siri, no App Store or
  external TestFlight, no server-side writes beyond read-only API use.

## Verification

- songr: existing `npm test` (jest) + `npm run test:browser` (Playwright)
  must stay green every commit; new seam code lands with tests.
- iOS: `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
  xcodebuild -scheme <app> build test` — canonical command recorded in
  `.agents/repo-guidance.md` once the scheme exists (P1).
- Requirement 3: counts screen / log line compared against source-server
  API totals at S2, S3, and P1 acceptance.
