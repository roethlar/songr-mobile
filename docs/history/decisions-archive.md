# Decisions archive

Provenance log. Entries moved verbatim from `.agents/decisions.md` when closed.

### 2026-08-30 - Architecture: songr core with Plex+Jellyfin sources; iOS thin shell

Status: Superseded (by 2026-08-31 "Architecture v3: standalone native app, direct to Plex/JF")

Decision:
songr (`~/Dev/roon-controller`) becomes the system core: a `LibrarySource`
plugin interface with Plex and Jellyfin sources added alongside Roon (Roon
keeps its current home-zone behavior), plus a phone-endpoint zone type over
the existing Socket.IO layer with a server-side per-zone queue. The iOS app
(this repo) is a thin shell: WKWebView presenting songr's UI, a native
AVPlayer-based endpoint client, and native CarPlay templates fed from
songr's browse API. Control plane runs through songr; audio streams direct
from source servers to endpoints. Backend question resolved as "both Plex
and Jellyfin, behind the plugin seam; Plex implemented first."

Reason:
Owner directive (2026-08-30, session goal): full delegation with direction
fixed — "plex/jf backend support, songr interface, ios & carplay app."
This reuses songr's UI exactly (it only ever talks to songr's own server),
reuses the owner's Plex/Jellyfin client knowledge from `~/Dev/vela`, and
avoids Roon's closed endpoint protocol on the phone. CarPlay renders native
templates in every architecture (Apple mandate), so UI reuse concerns the
phone face only.

Supersedes:
Plan v1's standalone-native-app architecture and its open Decision 1
(single-backend choice) in `docs/plans/music-player-v1.md` (rewritten to
v2 in the same change).

### 2026-09-05 - CarPlay album grid is not approved

Status: Active scope correction.

Decision: The owner explicitly stated, "album artwork grid in carplay is not
approved." The prior plan's album-card approval claim was incorrect. CarPlay
album presentation requires a separate choice before implementation; the current
pending grid/card renderer must not be landed. `docs/plans/carplay-browse.md`
owns the unresolved presentation and authorized remaining work.

This supersedes the older blanket artwork-grid directive for CarPlay albums.
The phone layout decision remains owned by `docs/plans/phone-navigation.md`.

