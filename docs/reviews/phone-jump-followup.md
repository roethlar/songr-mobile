# Phone artist jump correction

Date: 2026-09-04. Implementation: 13509f4. Scope: the already approved jump behavior in `docs/plans/phone-touch-index.md`, following the owner's physical-phone report. Source baseline: cf15016 (phone code unchanged from 4bea466).

## Defect and correction

The baseline rendered A artists beneath later letter headings and omitted other artist rows. Tapping M in the offline fixture reproduced ABBA under M. `ArtistsView` emitted each letter heading and a variable number of nested indexed rows from the same outer lazy ForEach.

The correction flattens letter headings and visual artist rows into one identified sequence. Every heading is now a direct lazy-stack target, and every artist row has a section-qualified identity. The existing down-column-then-across ordering, navigation links, counts, rail gesture, and layout breakpoints remain. No package sources changed.

A section-VStack attempt corrected missing rows in a small catalog but still landed at the wrong offset during a long backward jump in the full catalog. It was replaced by the flat sequence; it is not the landed implementation. Album and Genre section-wrapper experiments were also restored before final verification. This correction is specifically for Artists.

## Verification

- Debug simulator build passed using `build/touch-index-project/Songr.xcodeproj`; the owner's root generated project and signing settings were preserved.
- Canonical SongrKit tests: 63 passed, zero failures. No new unit test was added for the SwiftUI layout; the regression was reproduced and verified on screen.
- Baseline M selection showed ABBA under M: `.agents/screenshots/phone-jump-before-m.jpg`.
- Final flat-row build, real cached library: A → Z → M reached Z artists and then Madison Violet/Madonna/Madvillain at M, in both portrait and landscape. Landscape preserved the existing second column. Evidence: `.agents/screenshots/phone-jump-flat-library-m-portrait.jpg` and `phone-jump-flat-library-m-landscape.jpg`.
- The debug-only `-SongrForcePortrait` launch option was added beside `-SongrForceLandscape` to restore the scene's requested orientation for verification. Simulator hardware rotation is a separate control.
- The protected simulator was not erased, reset, or replaced. Its Plex-linked catalog remains present.
- The owner's physical iOS 27 device has not been rerun by the agent. The app must be rebuilt in Xcode to install this correction there.

## Navigation redesign

The owner subsequently requested reimagining the overflowing scope chips and scrolling controls. That is a separate design decision; this correction does not change the current rail or scope navigation. See `docs/plans/phone-navigation.md` for the proposed replacement.
