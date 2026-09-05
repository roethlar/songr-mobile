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

The owner requested reimagining the scope chips and scroll controls. The replacement is proposed in `docs/plans/phone-navigation.md`; it has not superseded this plan's controls yet. CarPlay has a separate approved plan in `docs/plans/carplay-browse.md`.

## Device follow-up (2026-09-04)

The owner reports that selecting a jump letter on the physical phone does not change the list. The approved tap/drag-to-jump behavior remains the scope. Correct the artist list identity and scroll destinations; verify that later letters show their own content and earlier letters remain reachable. The final correction and full-library checks are in `docs/reviews/phone-jump-followup.md`. CarPlay work remains in progress under its own plan.
