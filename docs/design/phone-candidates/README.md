# Compact phone navigation candidates

Status: candidate B selected by the owner on 2026-09-04 (owner wording:
"B"). Requirements and implementation scope remain in
`docs/plans/phone-navigation.md`. These files remain mockups, not app code.

Open `index.html` in a browser. It is self-contained and makes no network
requests. The owner requested PNGs and a copy of the interactive file in
their Downloads directory; these exports are generated from this source.

| Candidate | Navigation area | Placement | Tradeoff |
| --- | --- | --- | --- |
| A — Quiet tabs | 84 pt | Text tabs under the brand/settings header | Familiar placement; retains a separate header |
| B — One-line header | 44 pt | Brand, Artists, Albums, More, and Sort together | Most content space; Settings is inside More |
| C — Thumb bar | 48 pt | Artists, Albums, More, and Sort beneath the player | Easier thumb reach; Settings is inside More |

Measurements exclude the shared status bar, player, home indicator, and
library section heading. Every candidate reserves the same left-side jump
gutter. All are shown with the same example library and phone dimensions.
Album artwork uses the app's existing placeholder treatment so artwork does
not affect the navigation comparison.

The prototype supports Artists/Albums selection, More menus, secondary
sample destinations, alphabetical sorting, and tap/drag jumps within a
continuous sample list. The Downloads/Favorites samples illustrate access;
they do not implement persistent storage, background downloading, or audio
playback. Further sorting choices remain in the implementation plan.

## Verification

2026-09-04: rendered with an isolated headless Chrome profile under the
repo's ignored build directory. Inspected the Artists, Albums, More-menu,
and narrow-screen PNG exports. Checked all menu destinations, dismissal,
Z-to-M jumps, descending sort, and navigation fit at 390-point and
320-point device widths. The primary navigation targets remained at least
44×44 points and produced no browser runtime exceptions.

No iOS app build or SongrKit tests were run for this documentation-only
mockup. Physical touch ergonomics remain a device check after a layout is
selected. `git diff --check` is the repository check for this slice.
