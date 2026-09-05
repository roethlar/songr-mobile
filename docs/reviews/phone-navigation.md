# Compact phone navigation and full-catalog sorting

Verified 2026-09-05 against baseline `7cfefc8` plus the implementation committed
with this record. Authorization and final behavior: `docs/plans/phone-navigation.md`.

## Result

Candidate B replaces the separate header and chip scroller with one compact
44-point row. Artists, Albums, Added, and Played remain directly accessible;
More contains Genres, Most Played, Playlists, and Settings. All primary targets
are at least 44×44 points. Adaptive labels drop the brand first, then use
individual accessible icons. Native menus have one stable location outside the
adaptive label layout; this corrected blank menu labels after a text-size change.

Artists sort by name or album count. Albums sort by title, artist, year, added
date, last played, or play count, with both directions. Genres retain name
sorting. Choices persist per scope on the device. Recency/play facts come from
Plex; local Songr playback-history recording is still future work.

Sorting uses the complete catalog. Missing facts remain last, ties are stable,
and old cached albums lacking new optional fields still decode. Artist and
album indexes remain visible in every order. Album index targets follow artist
names when sorted by artist, otherwise album titles. Metadata orders jump to the
first matching title in the displayed sequence without regrouping it.

Album rows use native scroll-position binding and explicit layout targets. A
ScrollViewReader-only attempt sometimes landed one row off during a cold long
backward jump; native tracking corrected this. Scroll state is held below the
catalog computation so scrolling does not repeatedly sort the full library.
Changing sort recreates only that root's scroll state. Normal scope switches
retain paths and positions. Index lettering and the magnifier use sizes that fit
their cells at accessibility text sizes; the existing adjustable accessibility
action remains available.

## Verification

- Canonical SongrKit suite: 69 tests passed, zero failures. Six added tests cover
  metadata ordering in both directions, missing facts, tie stability, artist
  count/index mapping, alphabetical sections with # last, legacy decoding, and
  Plex field mapping.
- Regression proof: temporarily disabled descending comparisons and Plex added
  date/play-count mapping. The six focused tests produced eight expected
  assertion failures. Restored production code and reran the full suite: green.
  Local logs: `build/phone-navigation-negative-tests.log` and
  `build/phone-navigation-tests.log`.
- Generic iOS Simulator build passed for the final implementation with no
  warnings/errors in `build/phone-navigation-build.log`. Used the separate
  verification project; the owner's generated signing project was preserved.
  The working tree also contained independent pending CarPlay edits, preserved
  and excluded from this commit.
- Protected simulator, real Plex library: 3,982 albums. Refresh supplied added
  dates for all albums, years for 3,966, last-played dates for 129, and play counts
  for 125. Observed top results matched the cached server facts for year, added
  date, last played, and play count. Checked reverse year direction on screen.
- Portrait and landscape: all four direct destinations and both menus fit in one
  row. Added and Played loaded the expected server shelves with one tap. More
  exposed its destinations, and Settings opened successfully.
- Artists sorted by album count: Z → M → A reached the first matching artist in
  the sorted sequence. The landscape list retained its down-column presentation.
- Final album grid: cold title-order A → Z → M → A passed in landscape; artist
  order reached Z then Madison Violet/Madonna at M. Year order jumped to ZAMA
  ZAMA then midnight Cante without changing order. Repeated and backward jumps
  worked, including portrait after rotation. Changing field while positioned at
  M reset to the new sort's beginning.
- Sort field/direction survived relaunch. Switching Artists → Albums restored an
  already pushed album detail; Sort hid on the detail and returned at the root.
  Ordinary scope switches retained the previously scrolled album position.
- Largest accessibility text size: all four primary icons, More, and Sort stayed
  visible; the alphabet no longer overlapped vertically. Restored the original
  simulator text-size setting afterward.
- Player bar present: verified with the existing offline preview fixture. The
  header, browse content, and index fit above the bar. Most full-library checks
  used an absent player bar.
- `git diff --check` passed.

## Evidence

- `.agents/screenshots/phone-navigation-header-portrait.png`
- `.agents/screenshots/phone-navigation-album-sort-menu.png`
- `.agents/screenshots/phone-navigation-albums-title-cold-m-landscape.png`
- `.agents/screenshots/phone-navigation-header-accessibility-xxxl.png`
- `.agents/screenshots/phone-navigation-header-player-bar.png` (fixture)

## Limits and next work

This change has not been installed or tested on the owner's physical iOS 27
phone. Physical touch/flick behavior, sustained magnifier feel, haptics, and
VoiceOver still need device review. The automation tool did not deliver a
scrolling drag to either the existing artist scroller or the new album grid;
this prevented a meaningful flick-scroll check. Index taps and target movement
were verified independently. A narrower phone was not created: the protected
simulator was reused throughout. The smallest icon header requires 276 points
including its padding, but narrow-device rendering remains unverified.

Favorites, downloaded audio, local history, and offline cold launch are not
implemented by this slice. The next approved priority is CarPlay browse
presentation under `docs/plans/carplay-browse.md`; saved-music work follows its
functional plan. No simulator erase, keychain reset, or signing-project
regeneration was performed.
