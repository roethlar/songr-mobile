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

- Standalone native player architecture is implemented; current direction
  lives in `.agents/decisions.md`. Landed implementation and historical
  verification entries are in `docs/history/state-archive.md`.
- CarPlay browse soft spots remain for on-screen assessment:
  `App/Sources/CarPlay/CarPlayBrowseController.swift` loads artwork
  sequentially within each cover row (separate tasks per row), and the
  pre-iOS 26 artists fallback consumes `CPListTemplate.maximumItemCount`.
  The current iOS 26 path uses condensed image rows. These code facts were
  rechecked as of 2470fdf; library-scale behavior remains unverified here.

## Next

- Reconcile the remaining phone/CarPlay verification coverage with the
  screenshots under `.agents/screenshots/` and `.agents/review/carplay-smoke/`;
  the earlier blanket claims that simulator approval and a first link were
  still required have been superseded (see Blockers).
- Sanity-check paging, cache writes, and letter jumps with the owner's real
  library on device after signing is configured. The current Apple
  entitlement status needs owner confirmation before real-car testing.

## Blockers

- Verification record conflict: the former Next items requested simulator
  approval and a first Plex link, but the standing simulator exception in
  `.agents/decisions.md` and the archived real-library screenshot record
  supersede those bases. Remaining on-screen coverage and the current link
  state cannot be established from the repo alone; no simulator was launched
  during this sweep.
- Device signing remains unconfigured in tracked `project.yml` as of
  2470fdf (no development team). Owner setup is needed for on-device work.
- CarPlay audio entitlement was recorded as requested, approval pending,
  on 2026-08-30. Apple's current status cannot be verified from repo evidence;
  retain this as an unverified external blocker to real-car testing only.
- `docs/plans/music-player-v1.md` still labels the server-based v2 plan
  ACTIVE, although the architecture v3 decision supersedes it. The plan is
  outside this sweep's record-only edit scope; reconcile its status before
  using it as an implementation plan.

## Verification

- See `.agents/repo-guidance.md` (Verification) for the canonical commands.
- Historical test/build results are archived, not current results. This
  docs-only sweep did not rerun Swift tests or an app build.

## Active Sources

- `AGENTS.md`
- `.agents/repo-guidance.md`
- `.agents/decisions.md`
- `.agents/machines.md` (including the protected simulator rule)

## Unrecorded Repo Memory

- Historical commit provenance is incomplete in this clone; see
  `.agents/machines.md`. Archived verification claims have not been rerun.
