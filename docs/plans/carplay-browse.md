# CarPlay browsing

Status: ARTIST READABILITY WORK AUTHORIZED; ALBUM PRESENTATION UNRESOLVED.
On 2026-09-05 the owner explicitly corrected the scope: "album artwork grid in
carplay is not approved." The earlier statement that album cards were approved
was incorrect. Do not implement or land the pending CarPlay album-grid/card
candidate. The owner has been asked to choose album-and-artist text rows or those
rows with a small cover thumbnail. Neither replacement is approved yet.

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
2. Resolve the album presentation with the owner before implementing it.
   An artwork grid or card layout is not approved. Preserve album-to-track
   navigation and play-from-the-tapped-track behavior in the chosen replacement.
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
experiments, not approved shipping work. Keep them out of commits while the
album presentation is unresolved. The 24-element image-row limit remains valid
baseline evidence, but does not authorize a grid as the album solution.

## Follow-up

After the first slice is assessed, address artwork responsiveness, the
pre-iOS 26 full-library fallback, and any real-car control issues found.
These do not expand the phone touch-index implementation.
