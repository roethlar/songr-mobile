"""Build a static, offline gallery; all nine options remain visible together."""
from html import escape
from pathlib import Path
import json

root = Path(__file__).resolve().parent
options = json.loads((root / "options.json").read_text())
panels = "\n".join(
    f'<article id="{option["id"]}">\n'
    f'  <h2>{option["id"]} · {escape(option["title"])}</h2>\n'
    f'  <a href="{option["id"]}.png" aria-label="Open option {option["id"]} at native size">'
    f'<img src="{option["id"]}.png" width="800" height="480" '
    f'alt="Native CarPlay screenshot: {escape(option["title"])}"></a>\n'
    f'  <p>{escape(option["detail"])}</p>\n'
    f'</article>'
    for option in options
)
document = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Songr · CarPlay album options</title>
<style>
:root { color-scheme: light dark; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
* { box-sizing: border-box; }
body { margin: 0; padding: clamp(16px, 3vw, 40px); background: light-dark(#f6f6f6,#121212); color: light-dark(#191919,#f2f2f2); }
main { max-width: 1660px; margin: auto; }
h1 { font-size: clamp(25px,3vw,38px); font-weight: 500; margin: 0 0 10px; }
h2 { font-size: 22px; font-weight: 500; margin: 0 0 12px; }
p { line-height: 1.5; margin: 10px 0 0; }
header { margin-bottom: 32px; }
header p, article p { color: light-dark(#515151,#bdbdbd); }
nav { display: flex; flex-wrap: wrap; gap: 12px 24px; margin-top: 16px; }
a { color: light-dark(#165cc0,#9bc1ff); text-underline-offset: 3px; }
.options { display: grid; grid-template-columns: repeat(2,minmax(0,1fr)); gap: 36px 28px; }
article { min-width: 0; }
article a { display: block; }
img { display: block; width: 100%; height: auto; }
footer { border-top: 1px solid light-dark(#d0d0d0,#434343); margin-top: 40px; padding-top: 16px; max-width: 1000px; }
@media (max-width: 900px) { .options { grid-template-columns: 1fr; } }
</style>
</head>
<body>
<main>
<header>
  <h1>CarPlay album layouts</h1>
  <p>All nine native presentations · Same 12 albums · 800 × 480 display · No option selected</p>
  <nav aria-label="Comparison formats">
    <a href="comparison.png">All nine on one sheet</a>
    <a href="carplay-options.pdf">PDF: one option per page</a>
  </nav>
</header>
<div class="options">
PANELS
</div>
<footer>
  <p>Click any screen to inspect it at native size. These are actual iOS 26 CarPlay Simulator captures, with system spacing and truncation. Other vehicle displays may show different density. The first album has no available cover in this preview.</p>
  <p>A and B offer the most readable names. C trades text width for density. D–I show every artwork-oriented family for comparison; including a grid here does not approve it.</p>
  <p>For the complete library, ordinary rows need a separate navigation/loading decision: this connection permits 500 list items, while the cached library has 3,982 albums. C–I can group multiple albums into each native item, in batches of at most 24. This twelve-album comparison does not prove full-library behavior.</p>
  <p>These letters apply only to this CarPlay comparison. The selected phone design B is unchanged.</p>
</footer>
</main>
</body>
</html>
""".replace("PANELS", panels)
(root / "index.html").write_text(document)
print(f"Created index.html with {len(options)} native captures")
