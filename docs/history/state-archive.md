# State archive

Entries rotated verbatim from `.agents/state.md` when landed or superseded.

## Rotated 2026-08-31 — Architecture v2 entries, superseded by the v3 pivot

(All songr-server integration below is dead under Architecture v3 — the
standalone app talks straight to Plex. songr-side branches live in
`~/Dev/roon-controller`, owned by another agent; nothing here was pushed.)

- Plan v2 ACTIVE: `docs/plans/music-player-v1.md` — songr core
  (source plugins + endpoint zones, work in `~/Dev/roon-controller`) +
  thin iOS/CarPlay shell (this repo). Architecture decision recorded in
  `.agents/decisions.md` (2026-08-30); owner gave full delegation.
- Seam design doc LANDED: `docs/design/songr-source-seam.md` —
  authoritative for implementation order (contract inventory with
  file:line cites, endpoint socket protocol, phased touch list).
- songr pre-S1 baseline: `main` @ 36004ac, 150 jest suites / 2528 tests
  green (2026-08-30, this machine).

- S1 DONE (2026-08-30): songr `endpoint-zone` branch, 11 local commits
  (fbfa091..b4175ca), never pushed. `/endpoint` namespace, registry with
  disconnect-grace, TransportHub multiplexing, server-owned queue,
  diagnostics enqueue gated behind ENDPOINT_DIAG. Suite 150/2528 →
  156/2645 green; Roon-only behavior unchanged with SOURCES_ENABLED off.
- S2 DONE (2026-08-30): songr same branch, 12 further commits
  (b5ef7fa..dbd7418), never pushed. LibrarySource contract + registry,
  PlexSource over injected fetch, `/api/sources` (+`/:id/search`,
  `/:id/albums/:albumId/tracks`), `/api/stream` Range proxy, source
  artwork via `/api/image`, `POST /api/transport/play-album`
  (`{zone_id, source_id, album_id, track_id?|start_index?}`;
  tapped track queues whole album, starts there; Roon
  `album_local_id` answers 501 — recorded divergence). Suite 156/2645
  → 168/2808 green as of dbd7418.
- CarPlay browse layer built here (ba93ec5): catalog-index client +
  letter drill-down templates; all Swift typechecks vs iphonesim SDK.
- Endpoint Swift client landed here (5594d6c): protocol v1 mirror over
  SocketIO, AVPlayer end/stall reporting; artwork thumbs (350705a).

- S3 DONE (2026-08-30): songr same branch, 3 commits (5a24fa8, 0382ffe,
  19b76f0), never pushed. Source catalogs merged into
  `/api/catalog/index` (albums carry `source_id`/`album_id`; Roon
  entries never do; artist merge only on unique normalized-name match);
  `ENDPOINT_TOKEN` auth — `X-Endpoint-Token` header gates
  `/api/sources/*`, `/api/stream/*`, play-album; `token` field in
  `endpoint:register`; unset = byte-identical LAN-open. Suite 168/2808
  → 171/2842 green as of 19b76f0. Divergences recorded in songr's
  `.agents/state.md` (album_id join map, header name, gate scope).
- App token wiring landed here: token in connect prompt (secure field,
  UserDefaults beside server URL), header on SongrAPI + AVURLAsset
  stream options, `token` in register payload. Sim build green.

- S4 DONE (2026-08-30): songr same branch, 8 commits (f33892c..e408932),
  never pushed. Plex PIN-link OAuth ported from Vela: `POST
  /api/sources/plex/link` (201 {pin_id, code, expires_at}), `GET
  .../link/:pinId` (pending | chooseServer w/ servers; 410 LINK_EXPIRED,
  502 PLEX_TV_ERROR), `POST .../link/:pinId/server`
  ({machine_identifier} → {status:"linked", source_id}); all behind the
  S3 token gate. Auth persisted at `PLEX_AUTH_PATH`
  (./config/plex-auth.json, 0600) with once-minted
  X-Plex-Client-Identifier; linked file BEATS PLEX_URL/PLEX_TOKEN env;
  live register-or-replace, machine-pinned source_id, connection
  re-resolve (local > plex.direct > relay, 60 s cooldown).
  `/api/sources` adds `plex_auth` + per-entry `auth`. songr settings UI
  runs the flow. Suite 171/2842 → 174/2895; UI vitest 103/1154 green.
- Shell fetch-wrapper landed here: WKUserScript (documentStart) wraps
  window.fetch to add `X-Endpoint-Token` on same-origin calls — without
  it the UI's Plex section hides behind the 401. Sim build green.

### Rotated ## Next

- End-to-end smoke: run songr with SOURCES_ENABLED, link Plex via the
  in-app plex.tv/link flow, confirm CarPlay A–Z shows Plex albums and
  tapped-track play reaches the phone endpoint zone in the sim.

### Rotated Known defects (v2 UI — the WebView shell they were filed
### against was deleted in the v3 pivot; the directive they produced
### governed the v3 rebuild, owner re-verification pending)

- Phone-view chips render half cut off, and the chip row exposes
  backend-specific entries (e.g. "Muse"). Owner: all chips must move to
  a phone/CarPlay-friendly layout before the UI is considered correct.
  (Reported 2026-08-31 during CarPlay smoke.)
- Phone view broken in portrait beyond the chips: alpha jump lists do
  not render and album count does not render. Portrait layout needs a
  real pass, not a chip-row fix. (Reported 2026-08-31.)
- CarPlay browse layout rejected by owner (letter drill-in, list-style
  albums, generic template feel). Governing direction now lives in
  `.agents/decisions.md` (2026-08-31 Browse UX directive): albums as
  artwork grid, artists as one indexed jump-list, songr look on both
  faces, no Roon in mobile tests. Verify at large-display size via
  Simulator `CarPlayExtraOptions`. (Reported 2026-08-31.)

### Rotated Blockers

- Owner decision pending: remote access path (phone → songr without
  VPN) — port-forward + Caddy/TLS on a domain vs Cloudflare Tunnel vs
  Tailscale fallback. Asked in chat 2026-08-30.
  [Superseded 2026-08-31: no songr server in v3 — the phone reaches
  Plex directly via plex.direct remote connections; no VPN question.]
- ~~Owner to supply Plex creds in `.env.local`~~ — superseded by S4
  PIN-link flow (env pair still honored when no auth file exists).
