# songr: multi-source seam design (Plex/Jellyfin sources + phone endpoint zones)

Status: design, ready to implement. Date: 2026-08-30.
Repos: `~/Dev/roon-controller` (songr — server `src/`, UI `ui/`), `~/Dev/vela` (reference only, read-only).
All `path:line` cites are relative to `~/Dev/roon-controller` unless prefixed `vela:`.

Goals recap:
1. `LibrarySource` plugin interface — Plex/Jellyfin become library sources **alongside** Roon (catalog, search, HTTP stream URLs). Roon stays special: Roon browse plays only to Roon zones.
2. Phone (iOS) registers over the existing Socket.IO layer as a playback zone; server owns its queue/now-playing; phone reports position/state.
3. Svelte UI unchanged where possible — a new zone just appears.
4. CarPlay app consumes songr's existing HTTP/socket API; suitable endpoints flagged below.

---

## A. Contract inventory

### A1. Socket events — UI-facing (default namespace)

Server socket layer: `src/server/socket/index.ts` (attachSocketServer). Sub-registrations: albumAction/classicBrowse/unifiedSearch/publicSongResolver/libraryAlbum/editorialItem sockets at src/server/socket/index.ts:159-193. UI receiver: `ui/src/lib/socket/register.ts` (full inbound surface listed at register.ts:201-213). UI emitter envelope: `ui/src/lib/socket/emit.ts` (`AckResponse<T> = {success:true; data?} | {success:false; error; code?}`, emit.ts:9-11, mirrored server-side at src/server/socket/index.ts:57).

#### Server→client (state push)

| Event | Payload | Server emit | UI handler |
|---|---|---|---|
| `core-status` | `{coreStatus: "discovering"\|"paired"\|"unpaired", coreInfo?: {id, displayName, displayVersion}}` | broadcast src/server/server.ts:290-292; per-socket hydrate src/server/socket/index.ts:198-201 | register.ts:29-36, 65-77 |
| `zones` | `{zones: Zone[]}` — **full snapshot**, emitted only on socket connect (index.ts:202) and as `{zones: []}` on core unpair (server.ts:352). No per-update snapshot rebroadcast (deliberate, comment in server.ts near :363: quadratic traffic) | index.ts:202; server.ts:352 | register.ts:38-40, 79-88 |
| `zone-updated` | `{zone: Zone}` — **per-zone diff** | server.ts:363-373 (from TransportService `zone-updated`, TransportService.ts:682/:696/:711) | register.ts:42-44, 90-92 |
| `zone-removed` | `{zone_id}` (server also emits `now-playing-updated` null for that zone, server.ts:376-383) | server.ts:376-377; TransportService.ts:736 | register.ts:46-48, 94-98 |
| `now-playing-updated` | `{zone_id, now_playing: NowPlaying \| null}` | server.ts:384-385; hydrate loop index.ts:203-208 | register.ts:108-114 |
| `seek-changed` | `{zone_id, seek_position: number}` — **~1 Hz, seconds** (UI depends on this cadence: ui/src/lib/stores/interpolatedSeekStore.ts:7-13, :48) | server.ts:419-420; TransportService.ts:752-768 | register.ts:104-106 |
| `queue-updated` | `{queue: ZoneQueue}` — full item-list snapshot per update (TransportService replaces items on Roon full pushes, splices on positional insert/remove deltas, TransportService.ts:775-826, :839-881) | server.ts:415-416; TransportService.ts:737/:784/:825 | register.ts:100-102 → queueStore keyed by `queue.zone_id` (ui/src/lib/stores/queueStore.ts:12-17) |
| `recently-played-inserted` / `-cleared` | epoch/revision-guarded payloads | server.ts:396-409 | register.ts:116-122 |
| `transport:error` / `queue:error` / `browse:error` | `{command, error, code?}` | index.ts:112-125 (sendError) | register.ts:50-53, 124-138 (toasts) |

Reconnect: server re-hydrates every new socket with `core-status` + `zones` + all `now-playing-updated` (index.ts:198-207); UI additionally re-runs REST `initializeStores` on `connect` (register.ts:145-154; ui/src/lib/stores/index.ts:66-74). Missed `queue-updated` are NOT replayed — the queue panel re-emits `queue:subscribe` on reconnect/zone change (ui/src/routes/library/UnifiedQueuePanel.svelte:43-50). Queue subscriptions are otherwise **server-driven**: on every `zone-updated` the server calls `transportService.subscribeQueue(zone.zone_id)` (server.ts:365-372) — no client handshake is needed for the broadcast stream. Error-delivery rule (index.ts:110-126): if the client passed an ack, errors go **only** through the ack; otherwise the topic event (`transport:error`/`queue:error`/`browse:error`) fires.

#### Client→server (commands, all with `AckResponse` ack)

Transport (handlers in src/server/socket/index.ts; each delegates to `TransportService`, cite = `socket.on` line):
- `transport:play-pause` `{zone_id}` — index.ts:211 → transportService.playPause (TransportService.ts:135). UI: ui/src/routes/+layout.svelte:188-195, NowPlayingOverlay.svelte:95-104, mediaSessionBinding.ts:61-63.
- `transport:next` `{zone_id}` — index.ts:224 → :154. `transport:previous` — index.ts:237 → :173. `transport:stop` `{zone_id}` — index.ts:250 → :192.
- `transport:seek` `{zone_id, seconds}` (finite, non-negative) — index.ts:263 → seek absolute (TransportService.ts:260-264). UI: +layout.svelte:269, NowPlayingOverlay.svelte:125-129.
- `transport:volume` `{output_id, value}` — index.ts:287 → setVolume (TransportService.ts:220-253; "relative" mode auto-selected for incremental outputs). UI: +layout.svelte:314, :347-351.
- `transport:settings` `{zone_id, shuffle?|auto_radio?|loop?}` (loop ∈ `['disabled','loop','loop_one','next']` — `LoopModeRequest = LoopMode | 'next'`, types.ts:31; validation index.ts:315-350) — index.ts:310 → setPlaybackSettings (TransportService.ts:279-298). UI: UnifiedQueuePanel.svelte:148-153.
- `transport:group` `{output_ids: string[]}` (≥2 non-empty strings, index.ts:362-378) — index.ts:357 → groupOutputs (:321-330). `transport:ungroup` — index.ts:386 → :345-350. UI: ZoneGroupingModal.svelte:163-171; +layout.svelte:204-223.
- `transport:standby` `{output_id, control_key?}` (idempotent) — index.ts:415 → :373-383. `transport:toggle-standby` (NOT idempotent) — index.ts:459 → :410-420. `transport:wake` — index.ts:507 → convenienceSwitch (:445-455). UI: ZoneGroupingModal.svelte:130-136.

Queue:
- `queue:subscribe` `{zone_id, max_item_count?}` — index.ts:548 → subscribeQueue (TransportService.ts:482-546; cap `MAX_QUEUE_SUBSCRIPTION_ITEMS = 50_000` TransportService.ts:86, checked index.ts:568-580); ack returns `QueueResponse {queue: ZoneQueue}` immediate snapshot (UI uses it: UnifiedQueuePanel.svelte:99-107).
- `queue:get` `{zone_id}` — index.ts:595 → getQueue (TransportService.ts:551-566), cache only, no subscribe.
- `queue:play-from-here` `{zone_id, queue_item_id}` — index.ts:614 → playFromHere (TransportService.ts:572-577). UI: UnifiedQueuePanel.svelte:120-125.
- `disconnect` — index.ts:636-639 (workspace/feature socket retirement; browse modules do their own cleanup: albumActions.ts:156, libraryAlbum.ts:151, editorialItem.ts:146).

Library/browse socket RPC families (Roon-bound; enumerated because CarPlay must NOT depend on them): `classic-session:acquire/release` + `browse:browse|load|pop|search` (contracts src/shared/classicBrowseContracts.ts:15-136; UI ui/src/lib/stores/classicBrowseSessionStore.ts:161,207,309-316); `unified-search:search|relationship|action|clear` (src/shared/unifiedSearchContracts.ts:68-181; ui/src/lib/unifiedSearchClient.ts:109-209); `public-song:resolve|action` (publicSongResolverContracts.ts:33-139); `library-album:open|select|cancel` → `library-album:versions|resolved|version-failed|failed` (libraryAlbumContracts.ts:70-171); `album-action:begin|execute|cancel` → `album-action:resolved|failed` (albumActionContracts.ts:59-145 — begin **requires** `zoneId` :65); `item-editorial:*` (editorialItemContracts.ts:95-234 — uses `ok:` discriminant, not `success:`); `muse:*` (MUSE_SOCKET_EVENTS, src/shared/native/museDspContracts.ts:35-45 — only contract carrying both `zoneId` and `outputId`, :146-151).

#### Core wire types (verbatim-critical fields)

`src/shared/types.ts` — UI imports these directly via `@shared` alias (ui/svelte.config.js:30; register.ts:20-27):
- `Zone` (types.ts:36-75): `zone_id, display_name, state: 'playing'|'paused'|'stopped'|'loading', seek_position?, is_play_allowed, is_pause_allowed, is_previous_allowed, is_next_allowed, is_seek_allowed, queue_items_remaining?, queue_time_remaining?, settings?: {loop?, shuffle?, auto_radio?} (types.ts:80-84), outputs?: ZoneOutput[]`.
- `ZoneOutput` (types.ts:89-114): `output_id, display_name, volume?: VolumeSettings, source_controls?: ZoneSourceControl[]`; `ZoneSourceControl` (types.ts:115-127): `control_key, display_name, status: 'selected'|'deselected'|'standby'|'indeterminate', supports_standby`; `VolumeSettings` (types.ts:140-160): `type, min, max, value, step?, is_muted`.
- `NowPlaying` (types.ts:163-207): `zone_id, title?, artist?, album?, duration?, seek_position?, image_key?, state, loop?, shuffle?` (album_artist/track_number/disc_number/year declared but never populated — TransportService.ts:1047-1062).
- `QueueItem` (types.ts:334-361): `queue_item_id: number, length?, image_key?, one_line/two_line/three_line` text lines. `ZoneQueue` (types.ts:366-371): `zone_id, items, max_item_count, updated_at`.

**Nothing in the UI parses zone_id / output_id / image_key / queue_item_id formats — all opaque** (UI recon conclusion; selected zone persisted as opaque string, ui/src/lib/stores/selectedZoneStore.ts:4, :30-59). This is the property that makes endpoint zones cheap.

### A2. HTTP routes the UI calls

Mounted in src/server/http/app.ts:129-160 (helmet :76, `express.json 32kb` :96, `/api` rate limit :110-119, separate `/api/image` limiter :120-127). UI client: `ui/src/lib/api/client.ts` + `ui/src/lib/native/api/client.ts`.

| Route | Purpose | Server | UI call |
|---|---|---|---|
| GET `/api/health` | subsystem health (503 body still parsed) | routes/health.ts | api/client.ts:280-295 |
| GET `/api/core`, POST `/api/core/switch` | core status / unpair+switch | routes/core.ts | api/client.ts:139-149 |
| GET `/api/onboarding` | first-run | routes/onboarding.ts | api/client.ts:156-158 |
| GET `/api/zones`, GET `/api/zones/:id` | zone snapshot (hydrate + REST backstop) | routes/zones.ts:16-42 → transportService.getZones/getZone | api/client.ts:297-300 |
| POST `/api/transport/{play-pause,next,previous,stop,seek,volume,settings}` (routes/transport.ts:33/:55/:77/:99/:121/:147/:173); GET `/api/transport/queue/:zoneId?maxItems=` (:214 — subscribes then returns `QueueResponse` snapshot); POST `/api/transport/queue/subscribe` (:251); POST `/api/transport/queue/play-from-here` (:286) | HTTP mirrors of the socket transport/queue commands (same payloads; 400s = `ErrorResponse`, types.ts:627-630) | routes/transport.ts | UI uses socket, not these — they are the natural CarPlay surface |
| GET `/api/image/:key?scale&width&height` | **artwork proxy** (see A4) | routes/image.ts:43-94 | ui/src/lib/imageUrl.ts:17-31 |
| GET `/api/artist-portrait/wide/:key` | wide-portrait namespace (never interchangeable with image keys) | routes/artist-portrait.ts | imageUrl.ts:34-50 |
| GET `/api/catalog/status`, `/index` (409→empty), POST `/refresh`; GET `/artists?query&limit`, GET/POST `/artists/:id/albums[/load]` | catalog lifecycle + search + discography | routes/catalog.ts (router.get :282,:300,:382,:430,:459,:488,:549; refresh POST :1104-1122) | api/client.ts:160-272 |
| GET `/api/catalog/most-played` (+performers/releases drills); `/api/catalog/playlists*` (contents/manage/native tracks/focus lifecycle/mutations) | native feature layer (optional build wall — src/server/libraryFeatures.ts:653-708) | routes/catalog.ts :668-1185 | native/api/client.ts:63-379 |
| GET/DELETE `/api/recently-played`; GET/POST/DELETE `/api/favorites[/:id]` | RP + favorites | routes/recently-played.ts, favorites.ts | api/client.ts:302-334 |

### A3. Catalog layer (what it stores, how it's populated)

- **Entities: artists + albums only** — no track entities, no playlists in the catalog store (tracks appear only as SHA-256 title-sequence fingerprint, src/shared/catalogContracts.ts:67-68). Snapshot `{coreId, revision, updatedAt, lastCompleteScanAt?, artists: ArtistRef[], albums: AlbumRef[]}` (src/core/catalog/CatalogService.ts:90-98).
- **Identity is deliberately Roon-free**: `localId` = random UUID (catalogContracts.ts:248-249; minted CatalogService.ts:330, collision-retry :2573-2594); "Roon browse/session keys are neither descriptor identity nor valid payload fields" (catalogContracts.ts:4-5). Matching is by normalized text (artists: `normalizedName`; albums: `[normalizedTitle, normalizedArtist]`, CatalogService.ts:1863-1867; + editionText/fingerprint in CatalogReconciliation.ts:485-506).
- **Population**: two browse walks only, `"artists" | "albums"` hierarchies (CatalogService.ts:50), paged `browse`/`load` ×100 rows (:1505-1541), top-level rows only (title/subtitle/imageKey, :1577-1584). Full re-walk with diff-based localId preservation (`buildCandidate` :1605-1702; reconcileRootArtists :1704-1805; reconcileRootAlbums :1850-1959). Selected-artist enrichment is a pure reconciler over a keyless observation contract (CatalogReconciliation.ts:59-76, :639-942). **No subscription-driven incremental sync exists**; triggers = pair → load persisted (:546-555), initial scan (src/server/initialCatalogScan.ts:44-97), manual POST /api/catalog/refresh (routes/catalog.ts:1104-1122), optional native-layer timer (src/server/native/nativeCatalogService.ts:294, :509-523).
- **Persistence**: one pretty-printed JSON file per core at `<CATALOG_PATH>/<sha256(coreId)>.catalog-v1.json` (CatalogPersistence.ts:74-76, :129, :161-165); atomic tmp+rename 0600 (:143-158); envelope version 3 (CatalogService.ts:171-181). `coreId` is opaque throughout — **a Plex/JF server id works as-is**.
- **Artwork in catalog**: opaque `imageKeyHint` harvested from browse rows (CatalogService.ts:1627, :1668), served through `/api/image` (catalogIndexContracts.ts:35).

### A4. How the UI gets artwork today (token-relevant)

Single funnel: `imageUrl(key,{width,height,scale})` → `/api/image/<encodeURIComponent(key)>?scale=fit&width=W&height=H` (ui/src/lib/imageUrl.ts:17-31; keys documented opaque, may contain `/ ? # %`, :2-6). Every call site goes through it (NowPlayingOverlay.svelte:324-326; UnifiedQueuePanel.svelte:300-302; mediaSessionState.ts:160-168; Unified* pages — full list in UI recon). Server: routes/image.ts:43-94 validates key ≤256 chars (:6, :51), scale/width/height (:56-79), then `ImageService.getImage` → Roon `get_image` behind a 32 MB memory LRU + 10 GB disk LRU keyed `sha256([key,scale,w,h])` (src/core/roon/ImageService.ts:100-103, :142-186, :249-283), `Cache-Control: public, max-age=86400, immutable` (:290-295). **No token ever appears client-side — this proxy is exactly the seam Plex/JF artwork needs.**

---

## B. Seam analysis (where Roon leaks, classified)

(a) **Already source-neutral** — reuse untouched:
- Catalog contracts + reconciliation + persistence (catalogContracts.ts:4-5; CatalogReconciliation.ts imports only contracts+crypto :1-17; CatalogPersistence.ts:5-8).
- Wire `Zone`/`NowPlaying`/`ZoneQueue`/`QueueItem` (types.ts:36-371) — normalized; ids opaque to UI.
- The 5-event transport vocabulary (`zone-updated`, `zone-removed`, `now-playing-updated`, `queue-updated`, `seek-changed`) and `transport:*`/`queue:*` command set.
- UI plumbing: socket client/emit/register, zones/nowPlaying/queue/selectedZone stores, TransportIcon, mediaSessionController (all listed "provably no change" in UI recon; register.ts is pure event→store dispatch over opaque ids).
- `/api/image/:key` proxy shape (opaque key in, bytes out).

(b) **Trivially neutralizable**:
- `QueueItem.queue_item_id` doc says "understood by Roon transport" (types.ts:336) — it's an opaque number to the UI; endpoint queue mints its own.
- `NowPlaying.image_key` / `FavoriteEntry.image_key` / `RecentlyPlayedEntry.image_key` "Roon image key, session-scoped" (types.ts:235-236, :311-312) — becomes "artwork key in the /api/image namespace"; needs durable source-tagged keys for source tracks (see C5).
- Status coupling: socketStatusStore/coreStore hard-wire "socket up ⇒ needs Roon core" (ui/src/lib/stores/socketStatusStore.ts:3-12; coreStore.ts:15); documentTitle bails when `!corePaired` (ui/src/lib/media/documentTitle.ts:37). Copy strings: `aria-label="Roon zones"` (+layout.svelte:581), "Select a Roon zone to see its queue." (UnifiedQueuePanel.svelte:288), "Roon preserves the first output's queue." (ZoneGroupingModal.svelte:264).
- `transport:group` UI assumption that all listed outputs are mutually groupable (ZoneGroupingModal.svelte:19-66) — server-side gating fix.
- Volume "relative" auto-mode (TransportService.ts:242-253) — endpoint zones just use absolute `number` volume.

(c) **Structurally Roon-bound** — do not generalize; route around:
- The entire play-action path: album/track playback exists only as Roon browse `item_key` action-chain discovery + one-shot execute leases (AlbumActionResolver.ts:516-588; BrowseSessionCoordinator.ts:205-215, :862-1069). There is **no "play these track IDs on this zone" primitive anywhere**.
- Roon queue ownership: read-only subscription + `play_from_here` (TransportService.ts:482-577); no add/remove/reorder. Endpoint queue manager is greenfield.
- Classic browse contracts (raw `itemKey`/`hierarchy`/`zoneId` on the wire — the one contract family carrying Roon keys, classicBrowseContracts.ts:194-243, :327), unified-search/public-song/library-album/album-action/editorial session RPCs, muse DSP.
- `playlistId` = native Roon sooid hex on the wire (playlistContracts.ts:62, :131).
- RoonClient/BrowseService/BrowseSessionCoordinator/ImageService internals; vendored SDK.
- CatalogService's *acquisition* half (browse session leasing + hierarchy paging, CatalogService.ts:33-60, :1505-1585) — but everything after `buildCandidate` consumes keyless rows, which is the extraction seam.

Exactly **three native-key leak points** in shared contracts overall: `playlistId` (HTTP), `imageKey`/`imageKeyHint` (socket+HTTP+`/api/image`), classic-browse options (socket). Everything else is opaque/server-minted.

---

## C. Proposed design

### C1. `LibrarySource` interface

New file `src/core/sources/LibrarySource.ts`:

```ts
import type { SelectedArtistObservation } from "../catalog/CatalogReconciliation";

/** A row as CatalogService.scanHierarchy already consumes: title/subtitle/imageKey, keyless. */
export interface SourceScanRow {
  title: string;
  subtitle?: string;          // album rows: artist name
  imageKey?: string;          // already-namespaced artwork key (see C5)
}

export interface SourceTrack {
  trackId: string;            // source-native id, opaque outside the source
  title: string;
  artist?: string;
  album?: string;
  durationSeconds?: number;
  trackNumber?: number;
  discNumber?: number;
  imageKey?: string;          // namespaced artwork key
}

export interface StreamResolution {
  url: string;                          // absolute URL on the media server
  headers?: Record<string, string>;     // auth headers; NEVER forwarded to clients
  expiresAt?: number;                   // epoch ms, for transcode sessions
  teardown?: () => Promise<void>;       // e.g. Jellyfin ActiveEncodings delete
}

export interface LibrarySource {
  readonly id: string;          // stable instance id (Plex machineIdentifier / JF server id)
  readonly kind: "plex" | "jellyfin";
  readonly displayName: string;

  start(): Promise<void>;       // validate connectivity/token; no scan
  stop(): Promise<void>;

  /** Catalog sync feed — same shape CatalogService's scan pages produce today. */
  scan(hierarchy: "artists" | "albums"): AsyncIterable<SourceScanRow[]>; // page-sized batches
  /** Selected-artist enrichment, feeding the existing pure reconciler. */
  observeArtist(artistName: string): Promise<SelectedArtistObservation | null>;

  /** Album track listing for queue construction (albumLocalId resolved to source ids by the sync layer). */
  albumTracks(sourceAlbumId: string): Promise<SourceTrack[]>;
  search(query: string, limit: number): Promise<SourceTrack[]>;

  /** Playable URL for one track. maxBitrateKbps => transcode; absent => direct/original. */
  streamUrl(trackId: string, opts: { maxBitrateKbps?: number }): Promise<StreamResolution>;
  /** Server-side artwork fetch for /api/image dispatch (see C5). */
  fetchArtwork(ref: string, opts: { width: number; height: number }): Promise<{ data: Buffer; contentType: string }>;
}
```

Catalog integration: extract a `CatalogScanProvider` seam from CatalogService — `scanHierarchy` (CatalogService.ts:1505-1541) becomes an injected provider; the Roon implementation wraps the current coordinated-browse pager; a `SourceScanProvider` adapts `LibrarySource.scan`. Everything downstream (`buildCandidate` :1605, reconcilers, persistence, status, revisions) runs unchanged with `coreId = source.id` (persistence already hashes opaque coreIds, CatalogPersistence.ts:74-76). One `CatalogService` instance per source; a thin `CatalogDirectory` maps sourceId→instance for routes.

Config (`src/config/env.ts` additions): `SOURCES_PATH` (default `<CONFIG_DIR>/sources.json`), loaded like roon-token.json (atomic 0600 pattern, env.ts:160-169). Shape:

```jsonc
{ "sources": [
  { "kind": "plex",     "id": "<machineIdentifier>", "displayName": "Plex (nas)",
    "baseUrl": "https://…:32400", "clientIdentifier": "<uuid>", "accessToken": "…" },
  { "kind": "jellyfin", "id": "<serverId>", "displayName": "Jellyfin",
    "baseUrl": "http://…:8096", "deviceId": "<uuid>", "userId": "…", "accessToken": "…" }
] }
```
`SOURCES_ENABLED` env flag, default **off** through Phase 1.

### C2. `PlayerEndpoint` zones + transport multiplexing

New `src/core/transport/TransportHub.ts` — the single object the socket layer and HTTP routes talk to. It exposes **exactly** TransportService's public surface (getZones/getZone/getNowPlayingAll/getQueue/subscribeQueue/playPause/next/previous/stop/seek/setVolume/setPlaybackSettings/groupOutputs/ungroupOutputs/standby/toggleStandby/convenienceSwitch/playFromHere + the 5 events) and routes by zone/output id:

```ts
export interface ZoneTransport {   // implemented by RoonTransportAdapter (wraps TransportService) and EndpointTransport
  ownsZone(zoneId: string): boolean;
  ownsOutput(outputId: string): boolean;
  getZones(): Zone[];
  getZone(zoneId: string): Zone | undefined;
  getNowPlayingAll(): NowPlaying[];
  getQueue(zoneId: string): ZoneQueue;
  subscribeQueue(zoneId: string, max?: number): Promise<ZoneQueue>;
  playPause(z: string): Promise<void>; next(z: string): Promise<void>; previous(z: string): Promise<void>;
  stop(z: string): Promise<void>; seek(z: string, seconds: number): Promise<void>;
  setVolume(outputId: string, value: number): Promise<void>;
  setPlaybackSettings(z: string, s: ZonePlaybackSettings): Promise<void>;
  playFromHere(z: string, queueItemId: number): Promise<void>;
  // group/standby family: RoonTransportAdapter implements; EndpointTransport rejects with a typed error
  on(event: "zone-updated" | "zone-removed" | "now-playing-updated" | "queue-updated" | "seek-changed", cb: (data: unknown) => void): void;
}
```

Endpoint zone ids: `endpoint:<deviceId>`; single output `endpoint:<deviceId>:out` with `volume: {type:"number", min:0, max:100, value, is_muted:false}`; no `source_controls`, no grouping. Hub rejects `transport:group` across transports and any group involving endpoint outputs with `transport:error` code `GROUP_UNSUPPORTED` (UI already toasts errors, register.ts:124-138). Wiring change: server.ts:363-420 listens on the hub instead of transportService; socket handlers (index.ts:211-635) and routes/transport.ts, routes/zones.ts take the hub. Zone snapshot on connect (index.ts:202) automatically includes endpoint zones → **the UI zone picker shows the phone with zero UI changes** (picker iterates `$zonesStore` rendering only `display_name`, +layout.svelte:582-593).

### C3. Endpoint queue manager

New `src/core/endpoint/EndpointQueueManager.ts` — per endpoint zone, server-owned (Roon zones keep Roon's queue untouched):

- State per zone: `items: EndpointQueueItem[]` (`{queue_item_id: number /*monotonic*/, track: SourceTrack, sourceId: string}`), `currentIndex`, `settings {shuffle, loop}` (`auto_radio` rejected), `positionSeconds`, `state`.
- Ops: `replaceAndPlay(tracks, startIndex)` (album/track play), `append(tracks)` ("queue"), `insertNext(tracks)` ("add-next"), `playFromHere(queue_item_id)`, `advance(reason: "ended"|"next"|"previous"|"error")` honoring shuffle/loop/loop_one.
- Projection: emits wire `ZoneQueue` (three_line = title/artist/album, `image_key` = namespaced artwork key) and updates the `Zone` (`queue_items_remaining/queue_time_remaining/settings`) + `NowPlaying` — the existing 5 events carry everything; UnifiedQueuePanel works as-is because `queue:subscribe`/`queue:play-from-here`/`transport:settings` are answered by the hub.
- On advance: resolves `streamUrl` via the source registry, then commands the device (C4). Stream resolution failure → skip-with-toast (`queue:error`) then try next, max 3 consecutive failures → stop.

### C4. Phone endpoint socket protocol

Separate Socket.IO **namespace `/endpoint`** (default namespace contract stays byte-identical for the UI). Registration follows the existing module-per-surface pattern (registerClassicBrowseSocket / registerLibraryAlbumSocket / registerEditorialItemSocket / registerAlbumActionSocket, all wired from attachSocketServer with per-module disconnect cleanup) — `registerEndpointSocket(io.of('/endpoint'), hub)` slots in with zero framework changes. New `src/shared/endpointContracts.ts` exports the event-name consts (learning from the repo-wide finding that inline event strings drift) + payload types. All commands ack `AckResponse`; mirror the default namespace's error rule (ack present → error only in ack, else `endpoint:error` event).

Device→server:
- `endpoint:register` `{deviceId: string /*stable UUID minted once on phone*/, displayName: string, model?: string, protocolVersion: 1, capabilities: {volume: boolean, maxBitrateKbpsCap?: number}}` → ack `{zone_id, resume?: {item: EndpointQueueItemMeta, positionSeconds, state}}`. Registration is idempotent: same `deviceId` reclaims the same `zone_id` and any surviving queue; a second live socket for the same deviceId supersedes and force-disconnects the old one.
- `endpoint:state` `{playbackId, state: "playing"|"paused"|"stopped"|"loading", positionSeconds, volume?: number, ts: number}` — **1 Hz while playing** (matches interpolatedSeekStore's ~1 Hz seconds assumption, ui interpolatedSeekStore.ts:7-13), immediately on any transition. Server maps to `zone-updated`/`seek-changed`/`now-playing-updated`.
- `endpoint:ended` `{playbackId}` → queue advance.
- `endpoint:error` `{playbackId, code: "http"|"decode"|"network"|"audio-session", message, recoverable: boolean}`; `endpoint:stall` `{playbackId, positionSeconds}` (buffering >2 s) → zone state `loading`; recovery via next `endpoint:state`.

Server→device (each carries `playbackId` where relevant; device ignores commands whose playbackId isn't current):
- `endpoint:play` `{playbackId: string /*uuid per queue-item start*/, url: string, startAtSeconds: number, meta: {title, artist?, album?, durationSeconds?, artworkUrl?: string /* /api/image/... absolute-izable */}, gapless?: {nextUrl?} }`
- `endpoint:pause` `{}`, `endpoint:resume` `{}`, `endpoint:stop` `{}`, `endpoint:seek` `{seconds}`, `endpoint:set-volume` `{value: 0-100}`.

Reconnect semantics:
- Socket disconnect ≠ zone death: EndpointRegistry starts a **grace timer (default 30 s, env `ENDPOINT_DISCONNECT_GRACE_MS`)**; zone flips to `state:"paused"` (device keeps playing offline is NOT assumed — phone pauses on socket loss after its own 5 s grace). On re-register within grace: same zone_id, server sends authoritative `endpoint:play` resume (current item, last reported position). After grace: `zone-removed` + queue retained in memory for `ENDPOINT_QUEUE_RETENTION_MS` (default 10 min) so a flaky drive doesn't lose the queue; UI's selectedZoneStore already survives temporarily-missing zones (selectedZoneStore.ts:30-59).
- Command idempotency: play/pause/seek acks are at-most-once; server treats a missing ack (5 s, mirroring emit.ts:72) as unknown and reconciles from the next `endpoint:state` rather than retrying blind.
- Clock: positions are device-reported seconds; server never extrapolates (UI interpolates client-side already).

Stream delivery to the phone: `GET /api/stream/:sourceId/:trackId?maxBitrateKbps=` — server resolves `streamUrl` and **proxies bytes with Range passthrough** (AVPlayer requires Range). Tokens live only in server→mediaserver headers (vela's rule: token in header, never in URL — vela:src-tauri/src/plex_library.rs:2102-2121; the one place vela puts `api_key` in a JF URL it flags as an acknowledged exposure, vela:src-tauri/src/source/jellyfin.rs:386 — do not copy). `endpoint:play.url` is a songr-relative `/api/stream/...` URL. Cost: audio relays through songr; acceptable on LAN; revisit with short-lived signed redirects if WAN matters (open question E-7).

### C5. Artwork for sources (no token to browser)

Keep `/api/image/:key` as the single namespace. Source keys are server-minted bounded markers: `src.<sourceId>.<sha1-16(ref)>` with the actual source ref (Plex thumb path / JF item+tag) stored in a small persisted map (`<DATA_DIR>/source-artwork-map.json`) — stays under the 256-char key cap (routes/image.ts:6, :51) regardless of path length (vela's b64 marker idea, vela:src-tauri/src/artwork.rs:16, :133-153, made length-safe). Image router: keys with `src.` prefix dispatch to `source.fetchArtwork` (Plex: `GET {base}/photo/:/transcode?width&height&minSize=1&upscale=1&url=<path>` with `X-Plex-Token` header, vela:plex_library.rs:1167-1180; JF: `GET /Items/{id}/Images/Primary?fillWidth&fillHeight&tag=` with `X-Emby-Token` header instead of vela's query token); everything else falls through to Roon ImageService. Reuse the existing disk LRU by keying the cache on the marker. Collision risk with real Roon keys: prefix chosen with `.` separators; add an assertion that no harvested Roon `imageKeyHint` starts with `src.` (log-once).

### C6. Multiplexed status & CarPlay surface

- `core-status` stays Roon-only. Add `source-status` (server→client, `{sources: [{id, kind, displayName, state: "ok"|"auth-required"|"unreachable", catalog: CatalogStatus}]}`) in Phase 2; UI ignores unknown events today (register.ts registers explicit handlers only) so this is additive.
- CarPlay (read-mostly, HTTP + one socket): **suitable now** — GET `/api/zones` (+`/:id`), POST `/api/transport/*` mirrors, GET `/api/transport/queue/:zoneId?maxItems=` (one-shot queue snapshot, routes/transport.ts:214 — ideal for pull-based CarPlay lists), POST `/api/transport/queue/play-from-here` (:286), GET `/api/catalog/index` (artists+albums+imageKeyHint; 409 `CATALOG_EMPTY` before first scan), GET `/api/catalog/artists?query`, GET `/api/catalog/artists/:id/albums`, GET `/api/image/:key`, GET `/api/recently-played`, GET `/api/favorites`, GET `/api/health`; default-namespace socket read-only for `zones`/`zone-updated`/`now-playing-updated`/`seek-changed` push. **Not suitable** (session-leased, browser-tab-shaped): `classic-session:*`, `library-album:*`, `album-action:*`, `unified-search:*` (they require requestId/tabId lease choreography and one-shot execute authority). Gap for CarPlay "play a Roon album": Phase 2 adds `POST /api/transport/play-album {zone_id, albumLocalId}` server-side wrapper around the existing AlbumActionService chain for Roon zones, and EndpointQueueManager for endpoint zones — one endpoint, hub-routed.

### C7. Plex/Jellyfin client specifics (cribbed from vela — with caveat)

**Caveat: vela is a video app; it contains zero music endpoints** (music explicitly excluded, vela:src-tauri/src/source/plex.rs:1569, vela:jellyfin.rs:1316-1323). Crib its auth/token/artwork/negotiation/teardown patterns; the music-specific paths below marked ⚠ are *not* validated by vela and must be verified against a live server before Phase 2 is "done".

Plex (patterns proven in vela):
- PIN link: `POST https://plex.tv/api/v2/pins?strong=false` with `X-Plex-Product`, `X-Plex-Version`, `X-Plex-Client-Identifier`, `Accept: application/xml` (vela:src-tauri/src/commands.rs:548-558); user visits `https://plex.tv/link/?pin={code}` (commands.rs:1457); poll `GET https://plex.tv/api/v2/pins/{id}` same headers until `authToken` (commands.rs:1575-1617); 15 s timeout client (commands.rs:6310-6316).
- Discovery: `GET https://plex.tv/api/v2/resources?includeHttps=1&includeRelay=1&includeIPv6=1` (vela:plex_library.rs:582-600); pin to `machineIdentifier`, verify via `GET {base}/identity` (3 s timeout) echoing the pinned id (plex_library.rs:657-690).
- All requests: token in `X-Plex-Token` **header** + `X-Plex-Client-Identifier` (plex_library.rs:1072-1074). Pagination `X-Plex-Container-Start/Size` (plex_library.rs:1604-1609).
- ⚠ Music browse: `/library/sections/{key}/all?type=8|9|10` (artist/album/track), `/library/metadata/{ratingKey}/children` (children pattern proven for video, plex_library.rs:1577-1589), search `/hubs/search?query=` (proven, :1001).
- ⚠ Music streaming: direct part URL from track metadata `Media/Part.key` re-rooted on the connection (pattern: plex_library.rs:2107-2137, `download=1`), or `/music/:/transcode/universal/start?...&maxAudioBitrate=` for `maxBitrateKbps` (vela proves the *video* universal-transcode shape incl. `session`, `protocol`, `directPlay/directStream`, teardown `DELETE /transcode/sessions/{session}`, plex_library.rs:1297-1501).
- Artwork: `/photo/:/transcode` proxy — proven (plex_library.rs:1167-1180).

Jellyfin (patterns proven in vela):
- Auth: `POST {base}/Users/AuthenticateByName` body `{"Username","Pw"}` with identity header `Authorization: MediaBrowser Client="…", Device="…", DeviceId="…", Version="…"` (vela:jellyfin.rs:53-74, :556-568); after auth append `, Token="…"`; for bare media fetches `X-Emby-Token` alone suffices (jellyfin.rs:165-171). 401 later → surface "reconnect required" sentinel (jellyfin.rs:197-201).
- ⚠ Music browse: `GET /Users/{uid}/Items?IncludeItemTypes=MusicArtist|MusicAlbum|Audio&Recursive=true&SortBy=SortName&StartIndex&Limit` (the `/Users/{uid}/Items` + params machinery is proven for video, jellyfin.rs:1239-1241, :1395-1427; music `IncludeItemTypes` values are not).
- ⚠ Music streaming: `GET /Items/{id}/PlaybackInfo?UserId=` first (proven negotiation, jellyfin.rs:356-371), then `/Audio/{id}/universal?MaxStreamingBitrate=…` or `/Audio/{id}/stream?static=true&mediaSourceId=…` — audio variants unproven; transcode teardown `DELETE /Videos/ActiveEncodings?deviceId&PlaySessionId` pattern proven (jellyfin.rs:236-252).
- Artwork: `/Items/{id}/Images/Primary?fillWidth&fillHeight&tag=` (jellyfin.rs:373-383) — but token via header through our proxy, not `api_key` query.
- General patterns worth keeping: retry-once-via-rediscovery (vela:plex.rs:1054-1075), timeout ladder (auth 15 s / probe 3 s / art fetch bounded), errors described without embedding token-bearing URLs (vela:source/mod.rs:762-776), transcode teardown backoff [200 ms, 600 ms] with 404=settled (mod.rs:738-760).

---

## D. Touch list (ordered, phased)

### Phase 1 — endpoint zone + queue manager (sources hardcoded off; Roon regression-safe)

1. **add** `src/shared/endpointContracts.ts` — endpoint event consts + payload types + `ENDPOINT_PROTOCOL_VERSION = 1`.
2. **add** `src/core/transport/TransportHub.ts` — ZoneTransport interface + hub (fan-in events, route commands by owned zone/output id, reject cross-transport group).
3. **add** `src/core/transport/RoonTransportAdapter.ts` — thin wrapper giving TransportService the ZoneTransport shape (no TransportService edits).
4. **add** `src/core/endpoint/EndpointRegistry.ts` — /endpoint namespace binding, register/dedupe/grace timers/supersede.
5. **add** `src/core/endpoint/EndpointTransport.ts` — Zone/NowPlaying projection, command→socket forwarding, state ingestion → hub events.
6. **add** `src/core/endpoint/EndpointQueueManager.ts` — queue ops, advance, ZoneQueue projection, stream resolution hook (stubbed while sources off).
7. **change** `src/server/server.ts` — build hub; switch event wiring at :363-420 to hub; attach /endpoint namespace.
8. **change** `src/server/socket/index.ts` — take hub in deps (:60-110 SocketDependencies); handlers :211-635 call hub; hydrate snapshot :202 already generic.
9. **change** `src/server/http/routes/transport.ts`, `routes/zones.ts` — constructor takes hub.
10. **change** `src/config/env.ts` — `ENDPOINT_DISCONNECT_GRACE_MS`, `ENDPOINT_QUEUE_RETENTION_MS`, `SOURCES_ENABLED` (default false).
11. **add** `src/server/http/routes/diagnostics-endpoint.ts` (dev-flag-gated) — enqueue a raw URL to an endpoint zone so the protocol is e2e-testable before sources exist.
12. **add** tests: `TransportHub.test.ts` (routing parity + passthrough), `EndpointTransport.test.ts` (register/reconnect/grace/supersede), `EndpointQueueManager.test.ts` (advance/shuffle/loop/play-from-here/failure-skip).

UI changes in Phase 1: **none required** (zone appears via existing snapshot/diff events). Known cosmetic wrinkles accepted until Phase 4: "Roon zones" menu label (+layout.svelte:581); green status dot requires `isCorePaired` (+layout.svelte:146, :576); tab title suppressed when unpaired (documentTitle.ts:37); ZoneGroupingModal lists endpoint output as groupable (server rejects safely); muse page selected on an endpoint zone shows its existing error path (museSessionStore is Roon-output-scoped, ui/src/routes/muse/ + museSessionStore.ts:5-11).

### Phase 2 — `LibrarySource` + Plex

13. **add** `src/core/sources/LibrarySource.ts` (C1 interface), `src/core/sources/SourceRegistry.ts`, `src/core/sources/sourcesConfig.ts` (load/validate `sources.json`).
14. **change** `src/core/catalog/CatalogService.ts` — extract `CatalogScanProvider` (inject; Roon impl wraps :1505-1541 pager). Smallest possible diff: provider supplies pages; buildCandidate onward untouched.
15. **add** `src/core/sources/plex/PlexAuth.ts` (PIN flow + resources + identity pinning), `PlexSource.ts` (browse/search/streamUrl/fetchArtwork), `src/server/http/routes/sources.ts` (GET /api/sources, POST /api/sources/plex/link + poll, GET /api/sources/:id/search, GET /api/sources/:id/albums/:albumId/tracks).
16. **add** `src/server/http/routes/stream.ts` — `GET /api/stream/:sourceId/:trackId` Range-passthrough proxy (C4).
17. **change** `src/server/http/routes/image.ts` — `src.` prefix dispatch (C5) + artwork-map persistence.
18. **change** `src/server/server.ts` — instantiate registry + per-source CatalogService when `SOURCES_ENABLED`; emit `source-status`.
19. **change** `src/core/endpoint/EndpointQueueManager.ts` — real stream resolution via registry; wire "play album/track from source X on endpoint zone" through routes/sources.ts or a `transport:play-source` socket command.
20. **add** `POST /api/transport/play-album` hub-routed wrapper (CarPlay + endpoint parity; Roon zones → AlbumActionService chain).
21. **add** tests: PlexSource contract test against recorded fixtures; stream proxy Range tests; image dispatch tests; catalog sync from a fake source (reusing CatalogService.test.ts harness patterns).

### Phase 3 — Jellyfin

22. **add** `src/core/sources/jellyfin/JellyfinAuth.ts`, `JellyfinSource.ts` (+fixtures/tests). Config already generic; image/stream/queue paths already source-agnostic. Verify ⚠ audio endpoints live.

### Phase 4 — catalog multiplexing + UI polish (the only phase touching `ui/`)

23. **change** `src/server/http/routes/catalog.ts` — index/search/status accept `?source=` or merge across catalog instances with a `sourceId` tag on artists/albums (contract addition to catalogIndexContracts.ts — additive optional field).
24. **change** `ui/src/lib/stores/libraryIndexStore.ts` — source-tagged identity in merge heuristics (:93-94, :474-578).
25. **change** `ui/src/routes/library/UnifiedLibraryMode.svelte` — route item actions by source (Roon items → existing action controllers; source items → play-album/endpoint path); zone-aware gating (source items unplayable on Roon zones and vice versa).
26. **change** `ui/src/routes/+layout.svelte` — zone menu label, status dot decoupled from `isCorePaired`.
27. **change** `ui/src/lib/stores/socketStatusStore.ts`, `coreStore.ts`, `ui/src/lib/media/documentTitle.ts` — per-source readiness; title works when any zone plays.
28. **change** `ui/src/lib/components/ZoneGroupingModal.svelte` — hide endpoint outputs from grouping; keep Roon copy Roon-scoped.
29. **change** `ui/src/routes/library/UnifiedQueuePanel.svelte` — copy ("Roon zone"), hide `auto_radio` for endpoint zones (settings echo already server-driven).
30. **change** `ui/src/lib/components/OnboardingFlow.svelte`, `AppSettingsMenu.svelte` — sources section; Roon-only onboarding no longer assumed.
31. **change** `src/shared/types.ts` — additive optional `Zone.transport?: "roon"|"endpoint"` and `NowPlaying.source_id?` if UI gating needs them (additive; UI ignores unknown fields today).

## E. Risks / unknowns / tests

Open questions (exact):
1. **Plex/JF music endpoints unverified** — vela is video-only. Q: do `/library/sections/{k}/all?type=8|9|10`, `/music/:/transcode/universal/start?maxAudioBitrate`, `/Audio/{id}/universal|stream` behave as expected on the owner's actual server versions? Gate Phase 2/3 "done" on a live probe script (pattern: src/tooling/native/*.local.ts probes).
2. **Where does "play a source album" enter?** Options: new socket command `transport:play-source {zone_id, sourceId, albumId, trackIndex?}` vs HTTP `POST /api/transport/play-album`. Doc assumes both route to the hub; owner should pick one canonical surface (recommend HTTP for CarPlay parity, socket wrapper later).
3. **Roon zones can never play source content** (no Roon API to push arbitrary URLs — TransportService has no such primitive; playback = browse action chains only, §B(c)). Q: is UI gating (Phase 4 #25) acceptable, or does the owner want a "not available on this zone" toast server-side too (hub can reject with typed `transport:error`)?
4. **Catalog index shape for multi-source** (Phase 4 #23): merged-with-tags vs per-source endpoints. Merged keeps `ui` diffs small; per-source keeps CatalogStatus semantics clean (status is per-coreId today, catalogContracts.ts:202-215). Recommend per-source instances + merged *index* response with `sourceId` tags.
5. **Endpoint auth**: neither socket nor HTTP has auth — the only gate is Socket.IO CORS from `CLIENT_ORIGIN` (comma-separated allowlist or `*`, default `*` for LAN-appliance use, src/server/socket/index.ts:67-83), and there is **no protocol-version handshake on the socket** (the only version gate anywhere is the `X-Roon-Controller-Playlist-Actions: "2"` HTTP header on two catalog routes). A phone on WAN needs at minimum a shared secret in `endpoint:register` + TLS. Q: is WAN in scope? If yes, add `ENDPOINT_TOKEN` env check at register time (cheap) before shipping Phase 1.
6. **Track catalog**: catalog stores artists+albums only (A3). Endpoint queue + CarPlay track lists therefore fetch tracks live per album (`albumTracks`) — fine for sources; for Roon albums, track lists come from `library-album:open` (session-leased, unusable from CarPlay). Q: is CarPlay Roon-album-tracks browse required for v1, or is album-level play enough? (Design assumes album-level play via #20.)
7. **Stream proxy bandwidth**: all endpoint audio relays through songr (C4). Fine on LAN; if WAN/cellular matters, add signed expiring redirect URLs instead — decide before iOS app hardcodes proxy semantics.
8. **`seek-changed` fan-out rate** with multiple endpoint zones at 1 Hz each — matches Roon's existing behavior (server.ts:419-420 broadcasts every tick to all sockets); no change needed, but note it scales linearly with zone count.
9. **Image-key namespace collision** (`src.` prefix vs real Roon keys) — mitigated by log-once assertion (C5); residual risk accepted.
10. **Vitest/socket drift**: event names are inline strings server-side (only MUSE exports consts). endpointContracts.ts exports consts; consider retrofitting a `TRANSPORT_SOCKET_EVENTS` const in the same commit that touches index.ts (cheap, prevents hub-migration typos).

Existing tests that protect the refactor:
- `src/core/roon/__tests__/TransportService.test.ts` — zone/queue/command semantics incl. queue diffs (:389), ordering (:616), playFromHere (:661) — must stay green untouched (Phase 1 never edits TransportService).
- `src/server/socket/__tests__/` — albumActions/classicBrowse/editorialItem/libraryAlbum/publicSongResolver/unifiedSearch handler tests. **Gap: no socket-level test exists for the `transport:*`/`queue:*` handlers** — write one against index.ts *before* the hub swap (pin ack shapes + error topics), then it guards the migration.
- `src/server/http/__tests__/app.test.ts` + `routes/__tests__/{core,catalog,image,health,onboarding,artist-portrait,diagnostics}.test.ts` — route contracts. Gap: no transport.ts/zones.ts route tests — same pre-refactor treatment.
- `src/core/catalog/__tests__/{CatalogService,CatalogReconciliation,CatalogPersistence}.test.ts` — protect the CatalogScanProvider extraction (Phase 2 #14).
- `src/server/__tests__/` — CatalogLifecycle, initialCatalogScan, listeningHandshake, indexShutdownOrder (shutdown ordering must incorporate EndpointRegistry).
- UI vitest: `ui/src/lib/__tests__/` zone/transport/queue store + mediaSession suites (UI recon §9: zone picker/transport/queue covered here, not in Playwright).
- Playwright (`ui/browser-tests/`, config ui/playwright.config.ts:6-37): **no spec covers zone picker/transport/grouping/queue** — fixture-based; unaffected but also no safety net.

New tests needed: hub routing parity (same command → same TransportService call, byte-identical events); endpoint protocol state machine (register→play→state→ended→advance; disconnect grace; supersede; stale-playbackId commands ignored); queue manager (shuffle/loop/loop_one/failure-skip caps); stream proxy (Range, token never in response headers/URL); image `src.` dispatch + cache; Plex/JF source contract fixtures; one Playwright smoke: fake endpoint zone appears in picker and transport buttons ack (fixture server can stub the hub).

---

## Phase 1 first commit (exact minimal diff scope)

Goal: introduce the hub with **zero behavior change**; every existing test stays green; no endpoint code yet.

1. **add** `src/core/transport/TransportHub.ts` + `RoonTransportAdapter.ts` — hub over exactly one transport (Roon). Pass-through methods + event re-emission, `ownsZone` = always true for now.
2. **change** `src/server/server.ts` — construct hub around transportService; switch the five `transportService.on(...)` wirings (:363-420) and the `getZones` snapshot uses to the hub.
3. **change** `src/server/socket/index.ts` — `SocketDependencies.transportService: TransportService` → `transport: TransportHub` (structural type; handler bodies unchanged except the receiver name).
4. **change** `src/server/http/routes/transport.ts`, `src/server/http/routes/zones.ts` — parameter type swap only.
5. **add** `src/server/socket/__tests__/transportHandlers.test.ts` — pins `transport:*`/`queue:*` ack + error-topic contracts against the hub (the missing regression net), written to pass against pre-hub behavior.
6. **add** `src/core/transport/__tests__/TransportHub.test.ts` — passthrough parity: every hub method delegates 1:1; every TransportService event re-emits with identical payload reference.

No `src/shared`, no UI, no config, no endpoint files in this commit. Follow-up commits in Phase 1 order: endpointContracts → EndpointRegistry/Transport (zone appears, no playback) → EndpointQueueManager + diagnostics enqueue route → grace/reconnect hardening.
