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

- The phone touch index is implemented under the owner's approved plan:
  `docs/plans/phone-touch-index.md`. Verification, device checks still to do,
  and the separately reproduced artist-row defect are recorded in
  `docs/reviews/phone-touch-index.md`.
- The owner confirmed the app opens on a physical iPhone (2026-09-04).
  Current signing and provisioning evidence lives in `.agents/machines.md`;
  the older blanket claims that device setup and CarPlay entitlement approval
  necessarily block testing are superseded by that evidence. Real-car
  behavior has not yet been verified.
- CarPlay is the next priority and the app's main purpose, per the owner.
  Current source assessment and a proposed first implementation slice are in
  `docs/plans/carplay-browse.md`; that slice is not yet approved.

## Next

- Review and approve the proposed CarPlay browsing slice, then verify the new
  presentation and full-library reachability against the captured baseline.
- Check sustained-touch magnifier appearance, haptic feel, cancellation, and
  VoiceOver on a device after rebuilding the phone change.
- Keep the pre-existing artist-row defect visible in the queue; its baseline
  reproduction is in the phone verification report. CarPlay takes priority.

## Blockers and open questions

- A current CarPlay simulator baseline is now recorded in the proposed plan.
  There is still no real-car verification or full catalog-count comparison.
- The owner has not yet confirmed whether their CarPlay input is touch,
  rotary/buttons, or both. The proposed plan preserves both input styles.
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
- `docs/plans/carplay-browse.md` (proposed, not approved)

## Unrecorded Repo Memory

- Historical commit provenance is incomplete in this clone; see
  `.agents/machines.md`.
