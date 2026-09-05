# Agent State

This file is the first place future agents should read for current repo state.
Keep it short: `## Now` holds only live entries; the `catchup` hygiene
sweep rotates landed or superseded entries verbatim to
`docs/history/state-archive.md` (create it on first use) — never summarize
them away, never let them pile up here. `handoff` is the fast snapshot and
rotates nothing. Write-time rules: volatile facts
(CI state, counts) carry `as of <commit>`; push status is never recorded
here — git owns it, and unpushed work is mentioned in the moment it
matters, never written down; a count or enumeration another file owns is
pointed to, never copied; machine-specific facts (local toolchains, host layout, per-clone posture) go to the tracked
`.agents/machines.md`, keyed by machine and dated — never here.

## Now

- Candidate B is implemented with direct Artists, Albums, Added, and Played
  access, a compact More menu, and full-catalog contextual sorting.
  `docs/plans/phone-navigation.md` owns the contract; `docs/reviews/phone-navigation.md`
  owns verification and device limitations. Favorites, local playback history,
  and offline Downloads remain subsequent functional slices. CarPlay browse
  presentation remains the next approved priority.

- The artist jump correction now uses direct, stable row targets and has passed full-library portrait/landscape simulator checks. `docs/reviews/phone-jump-followup.md` owns the results and physical-device limitation.

- The phone touch index is implemented under the owner's approved plan:
  `docs/plans/phone-touch-index.md`. Verification, device checks still to do,
  and the separately reproduced artist-row defect are recorded in
  `docs/reviews/phone-touch-index.md`.
- The owner confirmed the app opens on a physical iPhone (2026-09-04).
  Current signing and provisioning evidence lives in `.agents/machines.md`;
  the older blanket claims that device setup and CarPlay entitlement approval
  necessarily block testing are superseded by that evidence. Real-car
  behavior has not yet been verified.
- CarPlay presentation is unresolved under the corrected scope in
  `docs/plans/carplay-browse.md`; the owner says its album artwork grid is not
  approved. `docs/reviews/carplay-browse.md` owns the latest native layout and
  capacity evidence. Pending CarPlay renderers must not be landed yet.

## Next

- Resolve CarPlay album presentation with the owner, then implement the selected
  design under `docs/plans/carplay-browse.md`. Continue the authorized artist
  readability work within the native limits recorded in its review.
- Verify phone touch/flick behavior, sustained magnifier feel, haptics, and
  VoiceOver on the physical iOS 27 phone; `docs/reviews/phone-navigation.md` owns
  the current verification limits. The B header and sorting have already landed.
- Favorites and offline Downloads remain subsequent functional work in
  `docs/plans/phone-navigation.md`.

## Blockers and open questions

- CarPlay final visual verification remains outstanding. The display became available during phone testing; presentation and native capacity evidence are in `docs/reviews/carplay-browse.md`.
- The owner has not yet confirmed whether their CarPlay input is touch,
  rotary/buttons, or both. The approved plan preserves both input styles.
- The ignored generated project contains owner signing changes that are not
  represented in project.yml. Preserve them; see `.agents/machines.md`.
- `docs/plans/music-player-v1.md` still labels its server-based v2 plan ACTIVE,
  despite the superseding v3 decision. Do not use it as the current plan.

## Verification

- `.agents/repo-guidance.md` owns canonical verification commands.
- `docs/reviews/phone-touch-index.md` owns this change's results and limits.
  Earlier implementation results remain in `docs/history/state-archive.md`.

## Active Sources

- `AGENTS.md`
- `.agents/repo-guidance.md`
- `.agents/decisions.md`
- `.agents/machines.md` (including the protected simulator rule)
- `docs/plans/phone-touch-index.md`
- `docs/plans/phone-navigation.md` (header/sorting implemented; saved music proposed)
- `docs/reviews/phone-jump-followup.md`
- `docs/plans/carplay-browse.md` (approved; implementation in progress)
- `docs/reviews/carplay-browse.md`

## Unrecorded Repo Memory

- Historical commit provenance is incomplete in this clone; see
  `.agents/machines.md`.
