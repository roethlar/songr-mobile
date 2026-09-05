# CarPlay browsing

Status: ALBUM A SELECTED; FULL-LIBRARY NAVIGATION UNRESOLVED.

The owner selected A on 2026-09-05 after reviewing all nine native presentations:
plain, full-width album-and-artist rows without artwork.
`docs/design/carplay-options/A.png` is the selected visual reference, unchanged.
The uncommitted album-grid/card renderer must not be landed. The appearance is
settled; a change from continuous alphabet navigation to paging or letter
selection is not approved by the layout choice.

## Goal

Make the main car interaction quick and legible: jump to an artist or album,
recognize the result, and play the desired track. CarPlay is the product's
primary use case. The phone touch-index change does not alter CarPlay.

## Baseline evidence (before this slice)

The native controller is `App/Sources/CarPlay/CarPlayBrowseController.swift`.
On iOS 26 and later, Artists uses condensed image-row elements with blank
images, names, and album counts. Albums uses image-only grid elements, so
the grid does not supply album-title or artist captions. Both have native
section index titles. Tracks already play from the selected index.

Artwork loads sequentially within each letter's album group. The pre-iOS 26
artists fallback truncates at the native item budget. A temporary DEBUG
gallery can replace the root template using an app-tmp command file.

The installed iPhone development profile permits CarPlay, but no real-car
verification has been reported. As of 4bea466, a fresh baseline was captured
on the existing iOS 26 simulator after reconnecting its CarPlay display.
The current artist cards truncate names across two columns; the album grid
shows covers without captions. The system alphabet picker opens from the
native index, and selecting Z returns directly to the Z album section.
That proves late-letter access in the observed library, not complete catalog
counts. Baseline screenshots: `.agents/screenshots/carplay-before-artists.png`,
`carplay-before-albums.png`, `carplay-before-index.png`, and
`carplay-before-z.png` in the same directory. Older smoke screenshots may
represent different builds.

## Approved first slice

1. Use the native iOS 26+ row element for readable artist names and album
   counts, retaining the continuous library and native alphabet index.
2. Use selected A for albums: ordinary `CPListItem` rows with album title and
   artist name, no image. Preserve album-to-track navigation and playback from
   the tapped track. Resolve complete-library access before landing this change.
3. Make an approved presentation the normal debug and release path; retire the
   temporary gallery once its relevant presentation is adopted.
4. Verify late-letter access and native template limits at the owner's
   approximate 2,000-artist / 4,000-album scale. Do not silently declare the
   library complete if a template drops entries. Preserve the pre-iOS 26
   fallback during this slice and explicitly report its existing limitation.
5. Check artist, album, track, and now-playing screens on a functioning
   CarPlay display; capture the proposed layout before finalizing it.

Apple's templates own CarPlay touch and controller gestures. The phone's
custom drag/magnifier is not a CarPlay overlay. Input method is not yet
confirmed by the owner, so preserve both touch and rotary/button navigation.

## Implementation findings

`docs/reviews/carplay-browse.md` owns the native layout and capacity evidence.
The current artist-card experiment renders artwork tiles, not the requested
readable text list. The CarPlay display is available again. Ordinary native text
rows have a 500-item budget on the observed connection; the full artist library
exceeds that, so a readable, complete artist presentation still needs resolution.
Do not silently truncate it or accept tiles as a substitute.

The uncommitted album cards and batched artwork-loading changes remain
experiments, not approved shipping work. Keep these out of commits; they do not
match selected A. The 24-element image-row limit remains valid
baseline evidence, but does not authorize a grid as the album solution.

## Next navigation proof

The native list budget is smaller than the library. The public list API has no
scroll or alphabet-index selection callback for loading another range. Do not
promise seamless windowing or allow the native template to trim the library.
`docs/reviews/carplay-browse.md` owns the API and capacity evidence.

Proposed next proof: selected A with a native Jump control and explicit previous
and next ranges. Selecting a letter would load a bounded range starting there;
every album must remain reachable, including letters larger than one range.
Show the extra interactions and back behavior before seeking approval to change
the continuous-list contract. This is a proposed proof, not an approved
navigation decision or shipping change.

## Follow-up

After the first slice is assessed, address artwork responsiveness, the
pre-iOS 26 full-library fallback, and any real-car control issues found.
These do not expand the phone touch-index implementation.
