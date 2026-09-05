# Phone library navigation and saved music

Status: B HEADER AND SORTING IMPLEMENTED — verification: `docs/reviews/phone-navigation.md`. Implementation approved — owner wording: "okay, go", after selecting B and being told the next action was applying it to the phone UI. The owner then required direct Recently Added/Recently Played access and sorting beyond alphabetical order. This slice covers the compact header, existing destinations, and full-catalog sorting. Favorites, local history, and offline Downloads remain subsequent functional slices. Previously approved phone jump and CarPlay work retain their own authorization.

## Required behavior

- The jump list stays on screen for Artists and Albums. Preserve the existing reserved gutter, touch/drag selection, magnifier, and haptics. Keep existing Genres indexing as well.
- Redesign the scope chips, preserving album grids and artist presentation. Do not replace the jump list with a picker or drill-in.
- Include sorting, Recently Added, Recently Played, Most Played, Genres, Playlists, Favorites, and a download option to save music on the device for offline playback.
- Favor compact controls and content space over larger visual buttons. CarPlay remains the main purpose of the app.

## Selected compact navigation — candidate B

One 44-point row combines the brand/header and navigation, replacing both
the separate header and horizontal chip scroller:

    [Songr mark]    Artists    Albums    Added    Played    […]    [sort icon]

1. Artists, Albums, Recently Added, and Recently Played remain directly selectable. The owner explicitly corrected the implementation on 2026-09-05: "recently added and recently played cannot hide behind a dropdown". Use Added and Played as their compact visible labels, with full accessibility names. More uses an ellipsis icon and contains Genres, Most Played, Playlists, and Settings; Favorites/Downloads join it when functional. The active destination is checked. Dismissing the menu changes nothing.
2. Keep this row around 44 points high at ordinary text sizes. Use compact text and restrained selection styling, with non-overlapping full-height hit areas of at least 44×44 points. No large tiles, two-row shortcut dashboard, or horizontal scrolling.
3. The sort icon opens contextual sorting choices; it does not add another permanent toolbar. It has an accessible Sort label and selected order announcement.
4. When a secondary scope is active, More carries a selected state. Show its full name in the scrollable content heading rather than expanding the chip label or adding a permanent heading row.
5. Adapt for landscape and Dynamic Type without clipping or overlapping targets. Drop the decorative mark before shortening access. When scaled labels cannot fit, use individually accessible icons for all four primary destinations, More, and Sort; do not move either recent view into a menu. Keep at least 44-point targets and the visible jump rail.
6. Reuse SongrShell.select(_:), visited panes, and per-pane NavigationPath so scope switches preserve browsing position and shelf refresh behavior. Settings is reached through More; the player bar retains its existing position. Hidden panes must not receive accessibility focus.
7. The tradeoff is an extra tap for secondary destinations. Both recent views are primary destinations and must remain one tap away.

The old docs/design/phone-navigation-concept.html is retired, not an implementation reference.

The owner requested visual candidates after this proposal. Compare
docs/design/phone-candidates/index.html and its README: A keeps compact tabs
under the header, B combines navigation into the header, and C puts it in
a bottom toolbar. All retain the visible Artists/Albums jump rail. The
owner selected B on 2026-09-04; its placement now governs this layout
contract. A and C remain comparison alternatives only.

## Existing capabilities and affected code

- `App/Sources/UI/RootView.swift` owns the compact header, retained panes, per-scope sort preferences, and refresh on revisits.
- `ArtistsView.swift` keeps the stable direct lazy heading/row targets from `docs/reviews/phone-jump-followup.md` and derives letter targets from the rendered sort order.
- `AlbumsGridView.swift` renders concrete artwork rows with native scroll-position tracking. Scroll state lives below the catalog-ordering computation and resets only when its sort changes.
- `ScopeViews.swift` owns genres, playlists, and album shelves. Existing recent views use server ordering.
- `LibrarySource.swift` and `Plex/PlexSource.swift` now include optional album added/play timestamps and play counts for full-catalog sorts. Missing fields in older snapshots still decode. Favorites, downloads, and playback-history writes remain future capabilities.
- `CatalogStore.swift` persists artist/album metadata in Caches, keyed by server/library. This is not durable downloaded media storage; shelves and genre results still live in memory.
- `PlayerEngine.swift` constructs remote AVURLAssets from `source.streamRequest(for:)`. Offline playback needs a local-file resolver and startup that can show saved content without successful server discovery.

## Feature implementation after approval

### Approved B slice boundary

Implement the selected header with the existing seven browse scopes and Settings. Artists, Albums, Added, and Played stay directly accessible. Preserve navigation and scroll position on ordinary scope switches; reset only the sorted root when its order changes. Hide Sort on pushed pages and shelves with fixed ordering. Secondary scope headings scroll with content. Favorites/Downloads controls arrive with their functional slices.

Sorting is contextual, with a field and direction picker:

- Artists: Name (A–Z/Z–A), Album count (Most/Fewest first).
- Albums: Title, Artist (A–Z/Z–A); Year, Date added, Last played (Newest/Oldest first); Play count (Most/Fewest first).
- Genres: Name (A–Z/Z–A).

Persist field/direction per scope on this device. Use the full catalog, not a capped recency shelf. Plex album metadata supplies dates and counts; missing values stay last in both directions. Equal values use normalized name/title and stable ID. Existing snapshots lacking new optional metadata must still decode; catalog refresh supplies the new facts.

The index remains visible under every order. Alphabetical orders target letter sections with # last; artist-sorted albums index artist names. Nonalphabetical orders retain one continuous sequence and jump to the first matching artist name or album title. Map those matches to concrete visual rows without changing sort. Artists retain direct lazy heading/row targets; Albums use concrete rows, `scrollTargetLayout`, and native scroll-position binding for reliable cold backward jumps. Index lettering fits its available cells even at accessibility text sizes; the magnifier and adjustable accessibility action provide alternate access. Keep album artwork grids and artist down-column-then-across presentation.

### Later history and offline view work

Persist successful shelf/genre/playlist metadata so offline views can show saved data; retain it on refresh failure. Record confirmed local playback progress in a durable history store shared by phone and CarPlay so Recently Played reflects Songr listening. Keep local events separate from server history, merge recency using the latest timestamp, and avoid double-counting totals. Server history synchronization is a separate capability, not an assumed streaming side effect.

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

The B header, direct recent destinations, and full-catalog sorting are implemented. Verification and device limitations live in `docs/reviews/phone-navigation.md`. The separately approved CarPlay browse work remains the next priority under `docs/plans/carplay-browse.md`. Favorites, downloads, local history, and corresponding CarPlay entries remain subsequent functional work; B approval does not settle every proposed storage/history policy.

- Shipping slices run canonical SongrKit tests and app build from .agents/repo-guidance.md, using the separate verification project to preserve owner signing overrides. Respect the protected simulator in .agents/machines.md.
- Check narrow phone widths, portrait/landscape, large text, player bar present/absent, all menu destinations, selected states, navigation return, refresh, and VoiceOver. Compare available content space with the current UI.
- Verify tap/drag A → Z → M → A and repeated letters for Artists/Albums with real catalog data under every sort. Check visible content, not just selected letters.
- Test meaningful sorting/jump-map, persistence/isolation, backward decoding, history, manifest recovery, shared ownership, and local/remote playback behavior. Prove new regression tests fail with their fix removed, then restore.
- Download an album and mixed playlist, terminate the app, relaunch without network/server access, and browse/play/skip/seek on phone and CarPlay. Cover missing/partial/corrupt downloads, low storage, reconnect, cancellation, removal during playback, and account/library changes.
- Physical-device and background behavior remain unverified until exercised there; cached metadata or a warm app is not evidence of offline audio support.
- Update records and commit each completed slice; follow .agents/push-policy.md. Existing AppModel/CarPlayBrowseController edits belong to their approved CarPlay slice and must not be staged with this planning revision.
