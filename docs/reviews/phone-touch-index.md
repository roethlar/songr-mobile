# Phone touch-index verification

Date: 2026-09-04. Approved scope: `docs/plans/phone-touch-index.md`.

## Results

- Simulator build passed with the Xcode 26.6 toolchain and iOS 17 deployment
  target, using the separate verification project described in the plan.
- SongrKit sources are unchanged from f2d625d. All 63 tests passed under
  Xcode's macOS toolchain with a fresh in-repo scratch directory. Initial runs
  exposed a copied module-cache path and then missing XCTest under
  CommandLineTools; neither required a product-code workaround.
- The original generated project and its owner-configured signing settings
  were preserved. No physical-device app was installed or launched by the
  agent during this implementation.
- On the existing protected iPhone 17 Pro / iOS 26.0 simulator, the index
  stayed in one reserved gutter in portrait and landscape with the player bar
  visible. Tap-to-jump and drag-to-jump worked; Artists and Albums reached S,
  and Genres reached Jazz in portrait and Rock in landscape. An unavailable
  album letter did not move the list. No bubble remained after release.
- The automation sends brief gestures; it did not provide a reliable held
  touch capture of the magnifier. Sustained-touch appearance, cancellation,
  haptic feel, and VoiceOver adjustment still need a device interaction check.

Screenshots are under `.agents/screenshots/`:
`touch-index-artists-portrait.png`, `touch-index-albums-portrait.png`, and
`touch-index-genres-landscape.png`.

## Separate pre-existing artist-row defect

Preview artist rows disappear or show under the wrong letter after jumping.
This reproduces with the unchanged ArtistsView from f2d625d, built separately
under ignored `build/touch-index-baseline/` and run with
`-SongrUIPreview -SongrPreviewNowPlaying` on the same simulator. Close the
now-playing sheet, then tap M: ABBA appears beneath M. Evidence:
`.agents/screenshots/touch-index-baseline-m.png`.

The new touch-index build was restored after that comparison. This defect
predates the touch index; its cause has not yet been established. CarPlay
remains the owner's next priority.

## Artist-row follow-up

The defect described above was corrected after the physical-phone jump report. The final implementation and verification are recorded in `docs/reviews/phone-jump-followup.md`.
