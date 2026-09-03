#!/usr/bin/env node
/**
 * tcp-tap.mjs — transparent TCP proxy with HTTP request logging.
 *
 * songr deliberately logs no per-request HTTP lines, so the smoke test's
 * evidence of the app's `POST /api/transport/play-album` body (track_id)
 * is captured here at the wire, without touching server code. Pure
 * byte-pipe both ways (websockets pass through untouched); client→server
 * chunks that start with an HTTP method are logged with headers+body.
 * The X-Endpoint-Token header value is redacted from the log.
 *
 * Usage: node tcp-tap.mjs [listenPort] [targetPort]  (default 3444 → 3333)
 */
import net from "node:net";

const LISTEN = Number(process.argv[2] ?? 3444);
const TARGET = Number(process.argv[3] ?? 3333);
const METHOD = /^(GET|POST|PUT|DELETE|OPTIONS|HEAD|PATCH) /;

let n = 0;
const server = net.createServer((client) => {
  const id = ++n;
  const upstream = net.connect(TARGET, "127.0.0.1");
  client.on("data", (chunk) => {
    const head = chunk.subarray(0, 4096).toString("latin1");
    if (METHOD.test(head)) {
      const redacted = head.replace(
        /^(X-Endpoint-Token:).*$/im,
        "$1 <redacted>"
      );
      console.log(
        `[tap#${id}] ${new Date().toISOString()} client→server\n` +
          redacted.split("\r\n\r\n").slice(0, 2).join("\n---body---\n")
      );
    }
  });
  client.pipe(upstream);
  upstream.pipe(client);
  const drop = () => {
    client.destroy();
    upstream.destroy();
  };
  client.on("error", drop);
  upstream.on("error", drop);
});

server.listen(LISTEN, "0.0.0.0", () => {
  console.log(`[tap] ${LISTEN} → 127.0.0.1:${TARGET}`);
});
