#!/usr/bin/env python3
"""Draw the social preview cards of Maru: python3 site/social.py

Writes og.png (1200 x 630) for each language, for Open Graph and X, and og-github.png (1280 x 640) for the
social preview of the GitHub repository. A card is an HTML page, and Google Chrome takes the picture.
Needs Google Chrome on macOS, because the card uses the system fonts, as the site does.
With --keep it also leaves the HTML pages in site/, to open in a browser.
"""

import html
import json
import subprocess
import sys
from pathlib import Path

SITE = Path(__file__).resolve().parent
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
# The language code and the file of its card. The folders of the site are in build.py.
CARDS = [("en", "og.png"), ("zh-Hans", "og-cn.png"), ("ja", "og-jp.png"), ("es", "og-es.png"), ("de", "og-de.png"),
         ("ko", "og-kr.png")]
# The design is 1200 x 630. The GitHub card is the same design, a little larger, on a wider background.
SIZE, GITHUB_SIZE = (1200, 630), (1280, 640)

# The colors, the type, and the shadows are the tokens of style.css.
PAGE = """<!DOCTYPE html>
<html lang="{code}">
<meta charset="utf-8">
<style>
html, body {{ margin: 0; width: {width}px; height: {height}px; overflow: hidden; }}
body {{
  background: radial-gradient(60% 90% at 78% 62%, #FFE3E9, transparent 70%), #FFFFFF;
  color: #1D1D1F; -webkit-font-smoothing: antialiased;
  font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", sans-serif;
}}
:lang(zh-Hans) {{ font-family: "PingFang SC", sans-serif; }}
:lang(ja) {{ font-family: "Hiragino Sans", sans-serif; font-feature-settings: "palt"; }}
:lang(ko) {{ font-family: "Apple SD Gothic Neo", sans-serif; word-break: keep-all; }}
:lang(en) {{ font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", sans-serif; font-feature-settings: normal; }}
.card {{ position: absolute; left: 50%; top: 0; width: 1200px; height: 630px; margin-left: -600px; zoom: {zoom}; }}
.copy {{ position: absolute; left: 90px; top: 0; bottom: 0; width: 560px; display: flex; flex-direction: column; justify-content: center; }}
.brand {{ display: flex; align-items: center; gap: 22px; margin-bottom: 44px; font-size: 60px; font-weight: 700; letter-spacing: -0.03em; }}
.brand img {{
  width: 92px; height: 92px; border-radius: 22%;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.04), 0 4px 8px rgba(0, 0, 0, 0.04), 0 12px 24px rgba(0, 0, 0, 0.05), 0 0 0 0.5px rgba(0, 0, 0, 0.08);
}}
h1 {{ margin: 0; font-size: 84px; line-height: 1.08; font-weight: 700; letter-spacing: -0.03em; }}
:lang(zh-Hans) h1, :lang(ja) h1, :lang(ko) h1 {{ letter-spacing: 0; line-height: 1.2; }}
h1 span {{ display: block; white-space: nowrap; width: max-content; }}
h1 span + span {{ color: #FF2D55; }}
.device {{
  position: absolute; left: 700px; top: 64px; width: 410px; padding: 14px 14px 0;
  border-radius: 76px 76px 0 0; background: #1D1D1F;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.04), 0 4px 8px rgba(0, 0, 0, 0.04), 0 12px 24px rgba(0, 0, 0, 0.05), 0 32px 64px rgba(0, 0, 0, 0.08);
}}
.screen {{ position: relative; height: 640px; overflow: hidden; border-radius: 62px 62px 0 0; background: #F2F2F7; }}
.screen img {{ position: absolute; left: 0; top: 0; width: 100%; }}
.island {{ position: absolute; left: 50%; top: 32px; width: 128px; height: 38px; margin-left: -64px; border-radius: 999px; background: #000000; }}
</style>
<div class="card">
<div class="copy">
<div class="brand"><img src="icon.png" alt=""><span lang="en">Maru</span></div>
<h1>{headline}</h1>
</div>
<div class="device"><div class="screen"><img src="shots/today-{code}.webp" alt=""><img src="shots/today-bars-{code}.webp" alt=""></div><span class="island"></span></div>
</div>
<script>
// A long headline gets a smaller size, so each line fits the column.
const h1 = document.querySelector("h1");
for (let size = 84; size > 40 && Math.max(...[...h1.children].map(s => s.offsetWidth)) > 560; size -= 2) h1.style.fontSize = size + "px";
</script>
</html>
"""


def shoot(code, name, size):
    """Write the card of one language as an HTML page in site/, and take its picture."""
    parts = json.loads((SITE / "src/strings" / f"{code}.json").read_text("utf-8"))["home"]["h1"].split("|")
    headline = "".join(f"<span>{html.escape(part.strip())}</span>" for part in parts)
    page = SITE / f"{Path(name).stem}.html"
    page.write_text(PAGE.format(code=code, width=size[0], height=size[1], zoom=size[1] / SIZE[1], headline=headline),
                    "utf-8")
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
                    f"--window-size={size[0]},{size[1]}", "--virtual-time-budget=3000",
                    f"--screenshot={SITE / name}", page.as_uri()], check=True, capture_output=True)
    if "--keep" not in sys.argv:
        page.unlink()
    print(f"card {name}")


def main():
    for code, name in CARDS:
        shoot(code, name, SIZE)
    shoot("en", "og-github.png", GITHUB_SIZE)


if __name__ == "__main__":
    main()
