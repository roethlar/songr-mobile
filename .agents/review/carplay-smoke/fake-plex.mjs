#!/usr/bin/env node
/**
 * fake-plex.mjs — a standalone fake Plex Media Server for the CarPlay
 * end-to-end smoke test (no real Plex account or library needed).
 *
 * Serves the exact JSON shapes songr's PlexSource consumes (mirrors
 * roon-controller src/core/sources/plex/__tests__/plexFixtureServer.ts and
 * its fixtures/, which pin the PlexSource contract), but over real HTTP so
 * songr can be pointed at it with PLEX_URL/PLEX_TOKEN. Audio parts serve a
 * real AAC file with Range support so the /api/stream proxy and AVPlayer
 * on the phone endpoint get honest bytes.
 *
 * Catalog: 22 synthetic artists spanning A–Z, one album each, 3 tracks per
 * album — enough to exercise the CarPlay A–Z jump list, album drill-down,
 * and tapped-track (play-from-here) semantics.
 *
 * Usage: node fake-plex.mjs [port]   (default 32499)
 */
import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const PORT = Number(process.argv[2] ?? 32499);
const HERE = path.dirname(fileURLToPath(import.meta.url));
const AUDIO = path.join(HERE, "assets", "tone.m4a");

// 1x1 white JPEG (valid; enough for artwork plumbing).
const JPEG = Buffer.from(
  "/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRof" +
    "Hh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwh" +
    "MjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAAR" +
    "CAABAAEDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAA" +
    "AgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkK" +
    "FhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWG" +
    "h4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl" +
    "5ufo6erx8vP09fb3+Pn6/9oADAMBAAIRAxEAPwD3+iiigD//2Q==",
  "base64"
);

const ARTISTS = [
  "Aurora Fields", "Basalt Choir", "Cinder Coast", "Driftwood Parade",
  "Ember Lane", "Fjord Runners", "Glass Harbor", "Hollow Pines",
  "Iron Meadow", "Juniper Sky", "Kite Season", "Lantern Row",
  "Marble Arcade", "Northern Static", "Opal Divide", "Paper Mountains",
  "Quiet Engines", "River Atlas", "Slate Gardens", "Timber Waves",
  "Umber Valley", "Velvet Compass",
];
const ALBUM_TITLES = [
  "First Light", "Broken Maps", "Coastal Lines", "Daybreak Signal",
  "Echo Season", "Field Notes", "Golden Hour", "Half Remembered",
  "Inner Weather", "Journey Home", "Kindred Sparks", "Long Shadows",
  "Midnight Mail", "Night Gardens", "Open Water", "Parallel Lives",
  "Quiet Rooms", "Restless Maps", "Second Nature", "True North",
  "Under Current", "Violet Hours",
];
const TRACK_NAMES = ["Overture", "Middle Distance", "Closing Time"];

const artists = ARTISTS.map((title, i) => ({
  ratingKey: String(101 + i),
  type: "artist",
  title,
  thumb: `/library/metadata/${101 + i}/thumb/1`,
}));

const albums = ARTISTS.map((artist, i) => ({
  ratingKey: String(301 + i),
  type: "album",
  title: ALBUM_TITLES[i],
  parentTitle: artist,
  year: 2000 + i,
  thumb: `/library/metadata/${301 + i}/thumb/1`,
}));

/** trackKey = 1000 + albumIndex*10 + n (n = 1..3) */
const albumTracks = (albumIdx) =>
  TRACK_NAMES.map((name, n) => {
    const key = 1000 + albumIdx * 10 + (n + 1);
    return {
      ratingKey: String(key),
      type: "track",
      title: `${name} (${ALBUM_TITLES[albumIdx]})`,
      parentTitle: ALBUM_TITLES[albumIdx],
      grandparentTitle: ARTISTS[albumIdx],
      index: n + 1,
      parentIndex: 1,
      duration: 30000,
      thumb: `/library/metadata/${301 + albumIdx}/thumb/1`,
      Media: [{ Part: [{ key: `/library/parts/${key}/1/file.m4a` }] }],
    };
  });

const trackByKey = (key) => {
  const k = Number(key);
  if (k < 1000) return null;
  const albumIdx = Math.floor((k - 1000) / 10);
  const n = (k - 1000) % 10;
  if (albumIdx < 0 || albumIdx >= ARTISTS.length || n < 1 || n > 3) return null;
  return albumTracks(albumIdx)[n - 1];
};

const json = (res, body) => {
  const data = JSON.stringify(body);
  res.writeHead(200, {
    "Content-Type": "application/json",
    "Content-Length": Buffer.byteLength(data),
  });
  res.end(data);
};

const page = (rows, query) => {
  const start = Number(query.get("X-Plex-Container-Start") ?? "0");
  const size = Number(query.get("X-Plex-Container-Size") ?? "50");
  const slice = rows.slice(start, start + size);
  return {
    MediaContainer: { size: slice.length, totalSize: rows.length, Metadata: slice },
  };
};

const serveAudio = (req, res) => {
  const stat = fs.statSync(AUDIO);
  const range = req.headers.range;
  if (range) {
    const m = /^bytes=(\d*)-(\d*)$/.exec(range);
    let start = m && m[1] !== "" ? Number(m[1]) : 0;
    let end = m && m[2] !== "" ? Number(m[2]) : stat.size - 1;
    if (start >= stat.size) {
      res.writeHead(416, { "Content-Range": `bytes */${stat.size}` });
      return res.end();
    }
    end = Math.min(end, stat.size - 1);
    res.writeHead(206, {
      "Content-Type": "audio/mp4",
      "Content-Length": end - start + 1,
      "Content-Range": `bytes ${start}-${end}/${stat.size}`,
      "Accept-Ranges": "bytes",
    });
    return fs.createReadStream(AUDIO, { start, end }).pipe(res);
  }
  res.writeHead(200, {
    "Content-Type": "audio/mp4",
    "Content-Length": stat.size,
    "Accept-Ranges": "bytes",
  });
  fs.createReadStream(AUDIO).pipe(res);
};

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://127.0.0.1:${PORT}`);
  const p = url.pathname;
  console.log(
    `[fake-plex] ${new Date().toISOString()} ${req.method} ${p}${
      url.search ? url.search : ""
    }${req.headers.range ? ` range=${req.headers.range}` : ""}`
  );

  if (p === "/identity") {
    return json(res, {
      MediaContainer: {
        size: 0,
        machineIdentifier: "smoke0machine0identifier00000000000fake",
        version: "1.41.0.0000-smoke",
      },
    });
  }
  if (p === "/library/sections") {
    return json(res, {
      MediaContainer: {
        size: 1,
        Directory: [
          {
            key: "3",
            type: "artist",
            title: "Music",
            agent: "tv.plex.agents.music",
            scanner: "Plex Music",
          },
        ],
      },
    });
  }
  const section = /^\/library\/sections\/([^/]+)\/all$/.exec(p);
  if (section) {
    const type = url.searchParams.get("type");
    return json(res, page(type === "8" ? artists : albums, url.searchParams));
  }
  const children = /^\/library\/metadata\/(\d+)\/children$/.exec(p);
  if (children) {
    const key = Number(children[1]);
    if (key >= 301 && key < 301 + ARTISTS.length) {
      const rows = albumTracks(key - 301);
      return json(res, { MediaContainer: { size: rows.length, Metadata: rows } });
    }
    if (key >= 101 && key < 101 + ARTISTS.length) {
      const rows = [albums[key - 101]];
      return json(res, { MediaContainer: { size: rows.length, Metadata: rows } });
    }
    res.writeHead(404, { "Content-Type": "application/json" });
    return res.end("{}");
  }
  const metadata = /^\/library\/metadata\/(\d+)$/.exec(p);
  if (metadata) {
    const track = trackByKey(metadata[1]);
    if (track) {
      return json(res, { MediaContainer: { size: 1, Metadata: [track] } });
    }
    res.writeHead(404, { "Content-Type": "application/json" });
    return res.end("{}");
  }
  if (/^\/library\/parts\/\d+\//.test(p)) {
    return serveAudio(req, res);
  }
  if (p === "/photo/:/transcode" || /thumb/.test(p)) {
    res.writeHead(200, {
      "Content-Type": "image/jpeg",
      "Content-Length": JPEG.length,
    });
    return res.end(JPEG);
  }
  if (p === "/hubs/search") {
    return json(res, { MediaContainer: { size: 0, Hub: [] } });
  }
  res.writeHead(404, { "Content-Type": "application/json" });
  res.end("{}");
});

server.listen(PORT, "127.0.0.1", () => {
  console.log(`[fake-plex] listening on http://127.0.0.1:${PORT}`);
});
