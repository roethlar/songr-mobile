# Phone touch index

Status: IMPLEMENTED 2026-09-04. Verification and remaining device checks:
`docs/reviews/phone-touch-index.md`.

## Problem and approved behavior

On the owner's iPhone, the alphabet index draws additional columns without
reserving their width, covering browse content. The owner approved replacing
the tap-only index with a single-column touch-and-drag index with a magnified
letter. CarPlay is the product's priority and is the next work item.

## Scope

- Use one 44-point-wide gutter for the shared Artists, Albums, and Genres index.
- Fit the alphabet within the available height in either orientation.
- Preserve tap-to-jump; dragging selects letters and jumps the list without
  animated scrolling. Show a large letter beside the finger while interacting.
- Give selection feedback when an available letter is selected; unavailable
  sections remain dim and do not trigger a jump.
- Dismiss the bubble on release or cancellation, and support VoiceOver letter
  selection without requiring precise taps.
- Preserve the owner's generated project signing settings.

## Verification

- Run the canonical SongrKit tests and simulator build.
- Generate a separate verification project under ignored build/ so XcodeGen
  does not overwrite the owner's signing changes in Songr.xcodeproj.
- Use the existing protected simulator only; never erase or replace it.
- Check portrait and landscape, player bar visible, tap and drag selection,
  bubble dismissal, and all three browse scopes.

## Next

Assess the current CarPlay UI and prepare a concrete improvement plan.
CarPlay implementation requires approval of that plan.
