# Phone library navigation

Status: PROPOSED 2026-09-04; owner requested reimagining the overflowing chips and poor scrolling controls. Implementation of this redesign is not approved. The separately authorized artist scroll-target correction remains under `docs/plans/phone-touch-index.md`.

## Source and affected code

- Concept: `docs/design/phone-navigation-concept.html` (interactive design reference, not an app runtime dependency).
- Current shell, scope selection, visited-pane preservation, and navigation paths: `App/Sources/UI/RootView.swift`.
- Current rail and artist rows: `App/Sources/UI/ArtistsView.swift`.
- Album and genre browse roots: `App/Sources/UI/AlbumsGridView.swift` and `App/Sources/UI/ScopeViews.swift`.
- Existing theme, player bar, settings, navigation destinations, source loading, and playback remain native SwiftUI/AppModel behavior.

## Proposed change requiring owner ruling

Remove the horizontally scrolling scope chips and the narrow alphabet rail from the phone. Use a large current-view selector (for example, Artists with a downward chevron) and a separate Jump A–Z button. Each opens a native sheet with full-size tap targets. Keep all existing scopes reachable, preserve per-scope browsing state, and use a single full-width artist list with album counts below names. The tradeoff is one additional tap when switching scopes; no scope depends on discovering sideways scrolling.

This replaces the phone interaction in the prior touch-index plan and the phone column presentation where they conflict. It does not authorize custom CarPlay sheets, controls, or gestures. CarPlay keeps its separate approved plan and Apple's template constraints.

## Implementation contract after approval

1. Replace `SongrShell.chipRow` with a compact header. The selector displays the current scope and opens a sheet containing Artists, Albums, Genres, Playlists, Recently played, Most played, and Recently added. Reuse `select(_:)` so visited pane state and shelf refresh behavior are preserved. Show the selected option; tapping an option changes scope and dismisses the sheet.
2. Put Jump A–Z beside the selector for the root Artists, Albums, and Genres screens. Hide it for non-indexed scopes and pushed artist/album/track screens. Keep settings and the existing player bar reachable. Long scope names must wrap or adapt without pushing controls offscreen.
3. Derive available index titles from the same catalog sections each browse root renders. Disable the jump button while no sections are available. Present A–Z and # in a native sheet with an adaptive grid. Every letter target is at least 44×44 points. Unavailable letters are visibly disabled. Compact landscape must increase columns or allow ordinary vertical sheet scrolling rather than shrinking targets.
4. Use a fresh selection request for each letter tap so choosing the same letter twice still jumps. A concrete approach is a `BrowseJumpRequest` value carrying UUID, scope, and letter in the shell, passed into the corresponding `BrowsePane` and indexed root. Handle it inside that root's `ScrollViewReader`; never jump an invisible pane. Report active navigation depth from each pane so the shell does not expose Jump A–Z on pushed screens.
5. Preserve stable lazy scroll targets and direct row identity from the artist correction. Avoid an outer lazy stack of variable-height section containers: the full-library Z-to-M probe showed incorrect offsets with that approach. For album/genre grids, verify long backward jumps against the real catalog before selecting a section representation. No delayed repeated-scroll workaround without reproducing why it is needed.
6. Remove `AlphaJumpRail` after all phone callers migrate. Restore its gutter to content. Artist rows use one column in both orientations, with name allowed to occupy two lines and album count beneath it. Keep native vertical scrolling; no second custom drag gesture or magnifier overlay.
7. Use native accessible button and sheet semantics, selected states, Dynamic Type, and labels. Dismissing a sheet must not change scope or position. A letter selection dismisses the picker and exposes the corresponding content. Preserve album-to-tracks and tapped-track playback.

## Verification

- Use the canonical SongrKit tests and separate simulator build from `.agents/repo-guidance.md`; preserve the owner's ignored Xcode project and signing overrides.
- On the protected simulator, verify selector access to all seven scopes, navigation state on returning to a scope, and shelf refresh behavior.
- Verify A → Z → M → A jumps, including repeated selection of a letter and drag-free dismissal. Compare heading and visible content, not just the picker selection. Check Artists, Albums, and Genres with both the offline preview and the real cached catalog.
- Check portrait and landscape, minimum supported phone width, large text, and player bar present/absent. No clipped controls or horizontal chip scrolling; every sheet option remains reachable.
- Verify VoiceOver selection and physical iOS 27 behavior when available. Do not claim simulator results prove the owner's physical-device behavior.
- Update the verification record, state, and applicable phone decision when the approved implementation lands. Commit the completed slice and follow the repo push policy.
