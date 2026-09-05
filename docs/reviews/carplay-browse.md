# CarPlay browse verification

Status: PRESENTATION UNRESOLVED, updated 2026-09-05. The owner states that the
CarPlay album artwork grid is not approved. The earlier blanket approval claim
was incorrect; `docs/plans/carplay-browse.md` owns the corrected scope. Pending
CarPlay renderers must not be landed as an approved album presentation.

## Findings and working changes

- The proposed `CPListImageRowItemRowElement` renders four artwork tiles with captions on the observed 800×480 CarPlay display. It does not produce wide artist rows. Evidence: `.agents/screenshots/carplay-rejected-row-elements.jpg`. The `CPListImageRowItemCardElement` artist candidate was inspected again on 2026-09-05 and likewise showed large blank artwork tiles with truncated names. Neither is a confirmed readable single-column artist presentation.
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

On 2026-09-05 Simulator's I/O → External Displays → CarPlay reopened the protected
device's display successfully, without erase, replacement, or keychain reset.
The existing installed candidate showed artist cards with large blank artwork
areas and truncated names. Albums showed cover cards with small, truncated title
and artist captions. The owner then explicitly corrected the scope: "album
artwork grid in carplay is not approved."

Work on that album candidate stopped. A temporary diagnostic artist-style
switch was compiled but never installed; it was removed after the correction.
No CarPlay implementation has been committed during this resumed work. Album
text rows, with or without a small cover thumbnail, are awaiting the owner's
choice. Artist text rows still need a solution for the observed native list
budget without silently losing catalog entries. The display itself is available;
do not report it as a blocker.

## Preserved limitations

The pre-iOS 26 fallback is unchanged: plain artist rows are capped by the native item budget, and older album image rows are likewise bounded. A full-library redesign for that fallback is outside this slice. Native CarPlay touch and rotary/button behavior has not been verified in a real car. Artwork loading remains eager and sequential within each batch; broader loading policy remains a follow-up.
