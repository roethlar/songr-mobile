# CarPlay browsing

Status: PROPOSED 2026-09-04; awaiting approval for implementation.

## Goal

Make the main car interaction quick and legible: jump to an artist or album,
recognize the result, and play the desired track. CarPlay is the product's
primary use case. The phone touch-index change does not alter CarPlay.

## Current evidence

The native controller is `App/Sources/CarPlay/CarPlayBrowseController.swift`.
On iOS 26 and later, Artists uses condensed image-row elements with blank
images, names, and album counts. Albums uses image-only grid elements, so
the grid does not supply album-title or artist captions. Both have native
section index titles. Tracks already play from the selected index.

Artwork loads sequentially within each letter's album group. The pre-iOS 26
artists fallback truncates at the native item budget. A temporary DEBUG
gallery can replace the root template using an app-tmp command file.

The installed iPhone development profile permits CarPlay, but no real-car
verification has been reported. The existing simulator CarPlay window was
blank and capturing its display did not complete; there is no new on-screen
CarPlay baseline from this session. Restore a working CarPlay display before
judging a new layout. Existing smoke screenshots may represent older builds.

## Proposed first slice

1. Use the native iOS 26+ row element for readable artist names and album
   counts, retaining the continuous library and native alphabet index.
2. Use native album cards with cover, album title, and artist name instead
   of cover-only tiles. Preserve album-to-track navigation and
   play-from-the-tapped-track behavior.
3. Make the chosen presentation the normal debug and release path; retire the
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

## Follow-up

After the first slice is assessed, address artwork responsiveness, the
pre-iOS 26 full-library fallback, and any real-car control issues found.
These do not expand the phone touch-index implementation.
