# CarPlay album presentation comparison

Status: OWNER SELECTED A on 2026-09-05; captured before selection that day.

The owner chose the original `A.png`: plain, full-width album-and-artist rows.
The screenshots, gallery, and PDF remain unchanged, including their original
no-selection captions. The selected contract and remaining navigation work live
in `docs/plans/carplay-browse.md`.

The owner requested all options after correcting the claim that a CarPlay album
artwork grid was approved. This comparison presents nine native styles together,
without narrowing the choice to two text-row variants or approving any grid.
These option letters belong to this comparison; the approved phone candidate B
is a separate design.

- [All nine on one sheet](comparison.png)
- [Full-size gallery](index.html) — click any capture to inspect it at native size
- [PDF, one option per page](carplay-options.pdf)

`options.json` owns the titles, descriptions, and native API mapping. A and B are
full-width text rows, without and with artwork. C is a compact two-column layout.
D–I cover captioned artwork, both card treatments, unlabeled artwork, and both
shapes of title-only artwork. These are the distinct album-list presentation
families and meaningful shape/card variants in the preview, not every possible
color, accessory, crop, or row-wrapping permutation. Navigation action grids and
Now Playing are not album-list alternatives. Native CarPlay controls remain
system-managed in all captures.

## Construction and evidence

`PreviewController.swift` is a nonshipping replacement controller under docs.
It was copied into an isolated app project under `build/carplay-options-preview`;
the app sources in the production target were not changed for this comparison.
The preview uses the existing Plex-linked snapshot, selects the first twelve
albums in its A section, and supplies the same ordered sample to every renderer.
Selections have inert handlers and do not play music. It loads 240px artwork,
caches successful images, and uses a letter placeholder for unavailable covers.
The first album had no available cover during this capture.

The isolated project built successfully with Xcode's iOS Simulator SDK. Options
A–I were installed/launched on the protected, existing iOS 26 device and visually
inspected in the actual CarPlay display. Each was captured with:

```text
xcrun simctl io <protected-device> screenshot --display=2 <option>.png
```

All nine source PNGs are unedited 800 × 480 native captures. The partial next rows,
label truncation, spacing, and focus highlights come from the system renderer.
Clock and focus position differ between captures; dataset and display dimensions
do not. The index contains A because this preview includes only one letter.
This does not demonstrate the complete library or a full alphabet jump test.

`compose.swift` lays the original captures out in a three-column PNG and a
nine-page PDF. `build-gallery.py` produces an offline HTML gallery with all nine
options visible and links to original images. The native screens and composed
sheet were visually inspected. Image dimensions, PDF page count, and local
gallery references were checked. Browser rendering was not tested: the in-app
browser was unavailable. No package tests were rerun for these nonshipping
comparison artifacts; `git diff --check` is the applicable repository check.

The existing normal verification app was reinstalled and launched afterward,
and the phone window was restored. No simulator erase, replacement, keychain
reset, or production project regeneration occurred. Preview selection is not
installed as the normal app.

## What remains to decide

The full-width rows preserve more text. Their full-library behavior needs an
explicit plan: the observed connected template permits 500 items, while the
cached library has 3,982 albums. The image-row families can place multiple albums
in a native item, in batches of at most 24. Neither the sample screenshots nor
that grouping capability proves complete connected-library behavior. The
canonical capacity evidence is in
[`docs/reviews/carplay-browse.md`](../../reviews/carplay-browse.md).

The owner selected A. The next step is a concrete plan for complete-library
access within native limits. No paging, letter drill-down,
silent truncation, or grid implementation is approved by this comparison.

## Recreate the comparison files

Run from this directory, keeping compiler caches in the repository:

```sh
rtk proxy env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift \
  -module-cache-path ../../../build/carplay-options-preview/swift-module-cache compose.swift
rtk proxy python3 build-gallery.py
```

The native preview requires a separate generated project with a copy of `App`,
the repository package dependency, and this preview controller in place of the
copied CarPlay controller. Its launch argument is `-SongrCarPlayOption A` through
`I`. Do not replace shipping sources or overwrite the owner's root Xcode project
to recreate it. Simulator protection and toolchain details are owned by
`.agents/machines.md`.
