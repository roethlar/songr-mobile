# CarPlay browse verification

Status: IN PROGRESS, 2026-09-04; working changes based on 3fffa64. The owner approved `docs/plans/carplay-browse.md`. The layout is not finalized or ready to claim complete.

## Findings and working changes

- The proposed `CPListImageRowItemRowElement` renders as four artwork tiles with captions on the observed 800×480 CarPlay display. It does not produce wide artist rows. Evidence: `.agents/screenshots/carplay-rejected-row-elements.jpg`. The current working tree tries `CPListImageRowItemCardElement` for artists; that candidate has **not** been visually verified. Do not describe it as a confirmed single-column artist list.
- Album cards now carry artwork, title, and artist in the working tree. The original album-to-tracks and tapped-track playback handlers remain. The temporary gallery and its AppModel library-selection hook are removed.
- The old controller put all entries for a letter into one image-row item. An iOS 26 native serialization probe confirmed that only 24 elements survive; this is `CPMaximumNumberOfGridImages`. Jumping to Z in the baseline did not prove full-library coverage. The working controller now batches artists and albums within each letter and artist detail page, retaining the native section index. It respects the native item and section budgets.
- A process sample during the first card attempt found the main thread spending nearly all sampled time serializing CarPlay template updates and PNG images. The old artwork loop mutated each attached element separately. The working loop builds each batch off-template and publishes it once, with a generation check after loading. Responsiveness of that change is still unverified.
- The cached library inspected during this work contains 1,131 artists and 3,982 albums. Counts reflect the protected simulator cache on 2026-09-04, not an asserted server total.

## Checks

- Canonical SongrKit unit tests: 63 passed, zero failures. No package code changed.
- Debug and Release simulator app builds: passed with the current working source and the separate verification project. The ignored root Xcode project and owner signing overrides were preserved.
- Native capacity probe: the original unbounded row retained 24 of 2,000 and 24 of 4,000 entries. Batches of 24 retained all 2,000 entries across 84 rows and all 4,000 across 167 rows, including a secure archive round trip. The probe fails if bounded rows lose entries and also asserts that the unbounded baseline demonstrates truncation.
- The connected Songr CarPlay scene reported a 500-item / 200-section budget. The standalone probe process has a smaller default budget, so it archives each row in its own template. Its result proves element retention, **not** full connected-template rendering, selection, or all catalog entries on screen.
- Final artist/album presentation, alphabet picker, late-letter access, artist-to-albums, album-to-tracks, and tapped-track/Now Playing behavior remain to be checked in the final build. Real-car verification remains outstanding.

The runnable probe source is `docs/reviews/carplay-capacity-probe.swift`. Compile it with Xcode's `xcrun swiftc -parse-as-library -target arm64-apple-ios26.0-simulator`, the iPhoneSimulator SDK, an in-repo module cache and output path; launch the resulting executable with `simctl spawn` on the protected simulator. It uses synthetic labels, changes no library data, and requires iOS 26 or later.

## UI verification status

The simulator shut down during the session (cause unverified). It was booted again without erasing, replacing, or resetting it, and its Plex-linked catalog remains available. The CarPlay window initially came back black. Repeated attempts through Simulator's external-display menu did not reopen a working CarPlay window; only the phone window remained. The owner was asked to reopen Simulator → I/O → External Displays → CarPlay. The display subsequently became available during the phone follow-up; its artist-card candidate still showed a large blank artwork tile rather than the required wide text row. The CarPlay window was closed temporarily to keep phone test clicks from being redirected to it. Reopen it for the remaining CarPlay work; do not treat the earlier disconnect as an ongoing blocker.

The latest working Debug build was installed and launched on the protected simulator after these changes. Once the display is available, inspect the artist-card candidate before choosing it, and verify both tabs and playback. If no native image-row style can provide the required wide artist list, surface that design constraint instead of silently accepting a grid or truncating the library.

## Preserved limitations

The pre-iOS 26 fallback is unchanged: plain artist rows are capped by the native item budget, and older album image rows are likewise bounded. A full-library redesign for that fallback is outside this slice. Native CarPlay touch and rotary/button behavior has not been verified in a real car. Artwork loading remains eager and sequential within each batch; broader loading policy remains a follow-up.
