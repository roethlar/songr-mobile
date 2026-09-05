# Phone library navigation and saved music

Status: REVISED PROPOSAL 2026-09-04. The owner rejected replacing the jump rail and then rejected a larger, two-row chip layout. Requirements: less screen space, touch friendly, simple. The compact replacement below awaits approval; this document does not authorize shipping changes. Previously approved phone jump and CarPlay work retain their own authorization.

## Required behavior

- The jump list stays on screen for Artists and Albums. Preserve the existing reserved gutter, touch/drag selection, magnifier, and haptics. Keep existing Genres indexing as well.
- Redesign the scope chips, preserving album grids and artist presentation. Do not replace the jump list with a picker or drill-in.
- Include sorting, Recently Added, Recently Played, Most Played, Genres, Playlists, Favorites, and a download option to save music on the device for offline playback.
- Favor compact controls and content space over larger visual buttons. CarPlay remains the main purpose of the app.

## Proposed compact navigation

One row replaces the horizontal chip scroller:

    Artists    Albums    More ∨    [sort icon]

1. Artists and Albums remain directly selectable. More opens a native menu containing Genres, Recently Added, Recently Played, Most Played, Playlists, Favorites, and Downloads. The active destination is checked. Dismissing the menu changes nothing.
2. Keep this row around 44 points high at ordinary text sizes. Use compact text and restrained selection styling, with non-overlapping full-height hit areas of at least 44×44 points. No large tiles, two-row shortcut dashboard, or horizontal scrolling.
3. The sort icon opens contextual sorting choices; it does not add another permanent toolbar. It has an accessible Sort label and selected order announcement.
4. When a secondary scope is active, More carries a selected state. Show its full name in the existing content heading rather than expanding the chip label or adding a permanent heading row.
5. Adapt for landscape and Dynamic Type without clipping or overlapping targets. At accessibility text sizes, allow an explicit compact menu fallback for scope selection; do not shrink text or hide the jump rail.
6. Reuse SongrShell.select(_:), visited panes, and per-pane NavigationPath so scope switches preserve browsing position and shelf refresh behavior. Keep settings and the player bar reachable. Hidden panes must not receive accessibility focus.
7. The tradeoff is an extra tap for the secondary destinations. The owner's preference for compact navigation takes precedence over giving every destination a permanent chip.

The old docs/design/phone-navigation-concept.html is retired, not an implementation reference.

## Existing capabilities and affected code

- App/Sources/UI/RootView.swift owns the seven current scopes, chip row, retained panes, and refresh on revisits.
- ArtistsView.swift owns the landed stable direct lazy heading/row targets. Preserve them; nested variable-height section containers failed long backward jumps. Evidence: docs/reviews/phone-jump-followup.md.
- AlbumsGridView.swift and ScopeViews.swift own artwork grids, genres, playlists, and album shelves.
- AppModel.swift already loads Genres, Playlists, Recently Added, Recently Played, and Most Played. These need better access, not placeholder implementations.
- LibrarySource.swift models include album title, artist, and year; they lack added/play timestamps, play counts, favorites, and download APIs.
- Plex/PlexSource.swift provides capped server-sorted shelves and authenticated direct-play requests. A capped shelf cannot stand in for whole-library sorting. No playback-history write API is present.
- CatalogStore.swift persists artist/album metadata. AppModel uses Caches keyed by server/library; this is not durable downloaded media storage. Shelves and genre results currently live in memory.
- PlayerEngine.swift constructs remote AVURLAssets from source.streamRequest(for:). Offline playback needs a local-file resolver and startup that does not require successful server discovery.

## Feature implementation after approval

### Sorting and recent views

Persist sort choice per library/scope. Artists support name ascending/descending. Albums support title, artist, year, added date, and last played. Preserve playlist track order. Add optional timestamps to catalog models/Plex decoding for full-library sorts; old snapshots must still decode. Missing values sort last, ties use normalized name/title and stable ID.

The rail remains visible under every sort. Alphabetic sorts target their sections; artist-sorted albums index artist names. Proposed nonalphabetical behavior: letters jump to the first matching album title in the displayed order without changing that order. Such matches are not contiguous; this interaction needs device review and must not silently change sort or remove the rail. Derive targets from the exact rendered sequence, mapping album items to their visual grid rows.

Persist successful shelf/genre/playlist metadata so offline views can show saved data. Retain it on refresh failure. Record confirmed local playback progress in a durable history store shared by phone and CarPlay so Recently Played reflects Songr listening. Keep local events separate from server history, merge recency using the latest timestamp, and avoid double-counting play totals. Server history synchronization is a separate capability, not an assumed effect of streaming.

### Favorites

Proposed first scope: artists, albums, and tracks, saved locally in Songr. Add accessible favorite/unfavorite actions to relevant rows, details, and Now Playing. Favorites offers Artists, Albums, and Songs sections. Favoriting an artist does not implicitly favorite/download all music. Removing a favorite does not remove downloaded audio.

Use a versioned atomic store in Application Support, keyed by account identity, backend, stable server ID, library ID, media kind, and item ID. Persist enough display metadata for offline use. Do not use tokens or transient server URLs as identities. Plex favorite synchronization is not included in the proposal.

### Downloads and offline playback

- Offer downloads for albums, individual tracks, and a snapshot of a playlist. Do not auto-download an artist's whole catalog or follow future playlist additions.
- Use a persistent download manifest and app-level background URLSession coordinator with bounded concurrency. Deduplicate shared tracks across collections. Obtain credentials at request time; do not persist tokens in media URLs/manifests.
- Save completed audio and required metadata/artwork in Application Support, excluded from backups. Publish ready state only after a successful, validated, playable download moves atomically from temporary storage. Unsupported media must fail visibly.
- Reconcile tasks/files after restart; support queued/downloading/ready/failed states, progress, retry, cancellation, authentication failure, partial responses, and insufficient storage. Proposed default: Wi-Fi downloads, with a visible cellular override.
- Downloads shows ready/partial states and storage used, plus Remove Download. Track shared collection ownership so removal does not break another retained collection; defer removing a file while playing it. Removing a download never deletes server media.
- Persist track ordering, titles, artist labels, duration, artwork, and playlist snapshots so browsing and queue creation require no server request. Make partially downloaded collections clear.
- Resolve playable local audio before requesting a remote stream. Do not silently count unavailable tracks as played or skip them without explanation.
- Cold launch with saved content must reach the library/Downloads even when server discovery or authentication refresh fails. Retry connections behind the offline UI. Isolate account/library data and stop old-account tasks/playback on sign-out.
- Share favorite data, offline metadata, history, and playback resolution with CarPlay. Expose Favorites and Downloads via supported templates within native budgets. Download/storage management stays on the phone.

## Work order and verification

The next owner ruling is the compact navigation layout. After approval, implement navigation/existing views and sorting, then favorites and download services/UI, then their CarPlay entry points. Do not ship inert feature controls in an intermediate slice. The separately approved CarPlay browse presentation work remains active under docs/plans/carplay-browse.md.

- Shipping slices run canonical SongrKit tests and app build from .agents/repo-guidance.md, using the separate verification project to preserve owner signing overrides. Respect the protected simulator in .agents/machines.md.
- Check narrow phone widths, portrait/landscape, large text, player bar present/absent, all menu destinations, selected states, navigation return, refresh, and VoiceOver. Compare available content space with the current UI.
- Verify tap/drag A → Z → M → A and repeated letters for Artists/Albums with real catalog data under every sort. Check visible content, not just selected letters.
- Test meaningful sorting/jump-map, persistence/isolation, backward decoding, history, manifest recovery, shared ownership, and local/remote playback behavior. Prove new regression tests fail with their fix removed, then restore.
- Download an album and mixed playlist, terminate the app, relaunch without network/server access, and browse/play/skip/seek on phone and CarPlay. Cover missing/partial/corrupt downloads, low storage, reconnect, cancellation, removal during playback, and account/library changes.
- Physical-device and background behavior remain unverified until exercised there; cached metadata or a warm app is not evidence of offline audio support.
- Update records and commit each completed slice; follow .agents/push-policy.md. Existing AppModel/CarPlayBrowseController edits belong to their approved CarPlay slice and must not be staged with this planning revision.
