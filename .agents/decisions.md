# Agent Decisions

Record durable repo decisions here. Do not use this as a chat log. Each entry should make
sense without conversation history and should name superseded guidance when relevant.

Keep this file to what is currently in force or still open. When a decision is
closed - superseded, or settled and retained only as the rationale for a rule that
now lives in its canonical home elsewhere - move it verbatim, in that same change,
to an archive under `docs/history/` (for example `docs/history/decisions-archive.md`);
never summarize or drop wording, the exact text is the record. Keep a single
pointer to the archive at the top of this file, not a stub per entry. The archive
is the provenance log; this file is what is in force or still open.

Archive: `docs/history/decisions-archive.md`

## Decision lifecycle

A decision moves through these states:

- **Open** - a finding has been assessed but not yet acted on. It lives in the
  `## Open Decisions` queue below, with the verified evidence, the options, and a
  standing recommendation. The process is unchanged until it is adopted; an agent
  records it rather than implementing on the spot.
- **Active** - a decision that is in force now.
- **Adopted YYYY-MM-DD** - an Open finding that has been acted on: its rule now
  lives in its canonical home (a procedure, template, or invariant). Note where the
  rule landed; the finding is retained in place as the rationale that led to it,
  until it is archived.
- **Superseded** - replaced by a later decision; name the replacement.

When an entry becomes purely historical rationale - Adopted or Superseded, with the
live rule now owned elsewhere - archive it per the rule above: move it verbatim to
`docs/history/`, do not leave a stub.

## Decisions

### 2026-09-04 - Phone touch index; CarPlay is the next priority

Status: Active

Decision:
The phone alphabet index uses one reserved touch gutter with tap and drag
selection, a magnified letter during interaction, and selection haptics.
It must not wrap into columns over browse content. This applies to Artists,
Albums, and Genres; implementation plan: `docs/plans/phone-touch-index.md`.
CarPlay is the product's main purpose and is the next work priority after
this focused phone change. Its UI continues to use Apple's native templates.

Reason:
The owner confirmed the app launches on a physical iPhone, reported the
two-column index overlapping content, requested a touchscreen-friendly
swipe/magnifier, and explicitly approved that interaction. The owner then
emphasized that CarPlay is the point of the app and needs work next.

Supersedes:
The 2026-08-31 phone-only ruling against scrubbing and a magnifier, preserved
in the implementation history. The CarPlay browse directive below remains
in force; this does not authorize a custom phone-style CarPlay gesture.

<!--
### YYYY-MM-DD - <Decision title>

Status: Active | Adopted YYYY-MM-DD | Superseded

Decision:
<What was decided.>

Reason:
<Why this is the durable rule or direction.>

Supersedes:
<Optional prior decision, doc, or rule.>
-->

### 2026-08-31 - Architecture v3: standalone native app, direct to Plex/JF

Status: Active

Decision:
The iOS app is a fully standalone native player. No songr server, no
home-server control plane, no webview. SwiftUI phone UI built in songr's
visual image (per the Browse UX directive below); CarPlay templates fed
from the same native models. Sources behind a native `LibrarySource`
protocol: Plex first (plex.tv PIN OAuth + connection discovery
local→remote→relay, as in `~/Dev/vela`, so the car works without VPN),
Jellyfin second (base URL + Quick Connect; remote reachability is the
owner's network concern — tunnel/reverse proxy — not app code). Playback
is on-device AVQueuePlayer with a native queue and play-from-track.
Catalog merge/indexing happens on-device. `~/Dev/vela` may be READ as
reference; nothing outside this repo is modified (hard boundary below).

Reason:
Owner requirement (2026-08-31): the car must not depend on a songr
server reachable on the home network; "the plex/jf connection should be
all that's required." Owner approved the native pivot explicitly ("yes").

Supersedes:
2026-08-30 "Architecture: songr core with Plex+Jellyfin sources; iOS
thin shell" (moved verbatim to `docs/history/decisions-archive.md`),
and plan v2 in `docs/plans/music-player-v1.md`.

### 2026-08-31 - Browse UX directive: songr look on both faces; no Roon in mobile tests

Status: Active

Decision:
Owner directive on library presentation, both phone and CarPlay:
1. Mobile testing runs against Plex/native sources, never Roon — Roon is
   not a mobile target (no phone player for Roon-owned zones).
2. Albums render as an artwork grid, not a list.
3. Artists: NO drill-down hierarchy. One continuous wide list with album
   count per row, text on background, with an alpha JUMP LIST rail that
   jumps within the list (Contacts-style), on both phone and CarPlay.
4. Phone face is songr's regular UI fit correctly to phone portrait and
   landscape (current portrait rendering is broken: chips, jump rail,
   album counts).
5. CarPlay face must read like songr, not a generic CarPlay audio app —
   within Apple's template mandate: albums via image-row (artwork grid
   rows), artists as a single indexed list (CPListSection index titles),
   no letter drill-in.

Reason:
Owner rejection of the letter-drill-in browse and list-style albums seen
in the 2026-08-31 CarPlay smoke ("I want alpha JUMP LIST, not drill
down"; "the carplay display should look like the app"). Templates remain
an Apple mandate for audio apps, so "look like the app" is carried by
information design (grid, jump rail, density), not custom drawing.

Supersedes:
The letter-range drill-in direction recorded 2026-08-31 in
`.agents/state.md` (Known defects) and the browse-hierarchy shape from
`docs/design/songr-source-seam.md` item 23 as it applies to the mobile
faces.

### 2026-08-31 - Hard repo boundary: nothing outside this repo changes

Status: Active

Decision:
NOTHING outside this repo may be created, modified, deleted,
or executed-with-side-effects without the owner's EXPLICIT per-action
approval in chat. This includes `~/Dev/roon-controller` (another agent
is working there), `~/Dev/vela`, `~/Dev/Bixi`, `~/Library`, the iOS
Simulator, and background processes. Any code this project needs from
roon-controller is COPIED (vendored) into this repo and evolves here;
no live dependency on that working tree, no edits there, ever. Build
artifacts stay in-repo (`xcodebuild -derivedDataPath ./build` or
equivalent). Simulator installs and any other out-of-repo side effect
require explicit owner approval each time until the owner grants a
standing exception. Standing exception granted 2026-08-31: iOS
Simulator boot/install/launch/screenshot for verification of this app.

Reason:
Owner directive (2026-08-31): "any code you need from roon-controller
needs to be copied here. NOTHING outside of this repo changes without
my EXPLICIT approval." Issued after this session's agents committed to
roon-controller's endpoint-zone branch and collided with the owner's
other agent working that repo.

Supersedes:
The 2026-08-31 "roon-controller is read-only" wording drafted earlier
this session, and the cross-repo editing practice used by the S-agents.

## Open Decisions (deferred - not yet adopted)

Assessed findings the owner chose to record as a future decision rather than
implement now. The process is unchanged until one is adopted. Each states its
verified evidence, the options, and a standing recommendation. When one is adopted,
flip its status to `Adopted YYYY-MM-DD`, note where the rule now lives, and keep the
finding here as the rationale until it is archived.

<!--
### YYYY-MM-DD - <Finding title>

Status: Open (deferred; no change made) | Adopted YYYY-MM-DD
-->
