#!/usr/bin/env python3
"""Draw the social preview cards of Maru: python3 site/social.py

Writes og.png (1200 x 630) for each language, for Open Graph and X, and og-github.png (1280 x 640) for the
social preview of the GitHub repository. It also writes the pictures of the repository README to docs/images/,
each for the light and for the dark theme of GitHub. A card is an HTML page, and Google Chrome takes the picture.
Needs Google Chrome on macOS, because the card uses the system fonts, as the site does.
With --keep it also leaves the HTML pages in site/, to open in a browser.
"""

import html
import json
import re
import subprocess
import sys
from pathlib import Path

import build

SITE = Path(__file__).resolve().parent
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
# The language code and the file of its card. The folders of the site are in build.py.
CARDS = [("en", "og.png"), ("zh-Hans", "og-cn.png"), ("ja", "og-jp.png"), ("es", "og-es.png"), ("de", "og-de.png"),
         ("ko", "og-kr.png")]
# The design is 1200 x 630. The GitHub card is the same design, a little larger, on a wider background.
SIZE, GITHUB_SIZE = (1200, 630), (1280, 640)
IMAGES = SITE.parent / "docs/images"
# The feature pictures of the README: the file and the block of the home page (build.stage).
FEATURES = [("reminders", "duo"), ("history", "history")]
FEATURE_SIZE = (480, 400)

# The hero of the README is the English card with round corners on a clear background, so it sits on the page of
# GitHub as a card. The light card is gray, because a white card has no edge on a white page.
HERO = """
body {{ background: none; }}
.card {{ overflow: hidden; border-radius: 40px; background: radial-gradient(60% 90% at 78% 62%, #FFE3E9, transparent 70%), #F5F5F7; }}
"""
# The dark hero: the dark tokens, the pink of iOS in dark mode, and a capture of Today in dark mode.
HERO_DARK = """
body {{ background: none; color: #F5F5F7; }}
.card {{
  overflow: hidden; border-radius: 40px; box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.08);
  background: radial-gradient(60% 90% at 78% 62%, #4A1424, transparent 70%), #161618;
}}
h1 span + span {{ color: #FF375F; }}
.device {{ background: #3A3A3C; }}
.screen {{ background: #000000; }}
"""
# A feature picture is a block of the home page on a card, with style.css. The dark card gets DARK_TOKENS.
FEATURE = """<!DOCTYPE html>
<html lang="en">
<meta charset="utf-8">
<link rel="stylesheet" href="style.css">
<style>
{tokens}
html, body {{ margin: 0; overflow: hidden; background: none; }}
.rcard {{
  position: relative; width: {width}px; height: {height}px; overflow: hidden; border-radius: 32px;
  display: grid; place-items: center; container-type: inline-size; background: {background};
}}
.rcard::after {{ content: ""; position: absolute; inset: 0; border-radius: inherit; box-shadow: inset 0 0 0 1px {ring}; }}
.rcard .wallpaper {{ max-width: none; height: 100%; box-sizing: border-box; border-radius: 0; align-content: center; box-shadow: none; }}
.rcard .device {{ --device-w: 270px; position: absolute; left: 50%; top: 44px; margin-left: -135px; }}
</style>
<div class="rcard">{block}</div>
</html>
"""

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
{extra}</style>
<div class="card">
<div class="copy">
<div class="brand"><img src="icon.png" alt=""><span lang="en">Maru</span></div>
<h1>{headline}</h1>
</div>
<div class="device"><div class="screen">{screen}</div><span class="island"></span></div>
</div>
<script>
// A long headline gets a smaller size, so each line fits the column.
const h1 = document.querySelector("h1");
for (let size = 84; size > 40 && Math.max(...[...h1.children].map(s => s.offsetWidth)) > 560; size -= 2) h1.style.fontSize = size + "px";
</script>
</html>
"""


def shoot(text, file, size, scale=1):
    """Write a card as an HTML page in site/, and take its picture."""
    page = SITE / f"{file.stem}.html"
    page.write_text(text, "utf-8")
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", f"--force-device-scale-factor={scale}",
                    "--default-background-color=00000000", f"--window-size={size[0]},{size[1]}",
                    "--virtual-time-budget=3000", f"--screenshot={file}", page.as_uri()], check=True, capture_output=True)
    if "--keep" not in sys.argv:
        page.unlink()
    print(f"card {file.name}")


# The colors of the app and the page in dark mode, for the dark README pictures. The site itself is light only.
DARK_TOKENS = """
    --bg: #000000;
    --bg-alt: #121214;
    --surface: #1C1C1E;
    --text: #F5F5F7;
    --text-2: #A1A1A6;
    --link: #FF6482;
    --focus: #FF6482;
    --tint-soft: rgba(255, 55, 95, 0.12);
    --ring-color: rgba(255, 255, 255, 0.12);
    --bar-bg: #1C1C1E;
    --bar-ring: var(--hairline);
    --tip-bg: #F5F5F7;
    --tip-text: #1D1D1F;
    --device-bezel: #3A3A3C;
    --device-screen: #1C1C1E;
    --app-label: #FFFFFF;
    --app-label-2: #8D8D93;
    --app-widget: #1C1C1E;
    --app-cap-off: #2C2C2E;
    --app-cap-line: #48484A;
    --app-banner: rgba(255, 255, 255, 0.14);
    --app-banner-rim: inset 0 1px 0 rgba(255, 255, 255, 0.45), inset 0 0 0 1px rgba(255, 255, 255, 0.24);
    --app-banner-text: rgba(255, 255, 255, 0.93);
    --app-banner-2: rgba(255, 255, 255, 0.85);
    --app-icon-ring: rgba(0, 0, 0, 0.2);
    --wallpaper: radial-gradient(120% 80% at 0% 0%, #4A1424, transparent 60%), radial-gradient(90% 70% at 100% 100%, #7A1B35, transparent 70%), linear-gradient(160deg, #1A080E, #33101C);
    --shadow-card: 0 1px 2px rgba(0, 0, 0, 0.3), 0 2px 4px rgba(0, 0, 0, 0.2), var(--hairline);
    --shadow-elevated: 0 4px 8px rgba(0, 0, 0, 0.2), 0 8px 12px rgba(0, 0, 0, 0.2), 0 2px 4px rgba(0, 0, 0, 0.2), 0 1px 2px rgba(0, 0, 0, 0.3), var(--hairline);
    --shadow-float: 0 2px 4px rgba(0, 0, 0, 0.4), 0 12px 24px rgba(0, 0, 0, 0.4), 0 40px 80px rgba(0, 0, 0, 0.5), var(--hairline);
"""


def card(code, size, extra="", dark=False):
    """The card of one language. The dark card has one capture of Today in dark mode, with its bars."""
    parts = json.loads((SITE / "src/strings" / f"{code}.json").read_text("utf-8"))["home"]["h1"].split("|")
    headline = "".join(f"<span>{html.escape(part.strip())}</span>" for part in parts)
    shots = [f"today-dark-{code}"] if dark else [f"today-{code}", f"today-bars-{code}"]
    screen = "".join(f'<img src="shots/{shot}.webp" alt="">' for shot in shots)
    return PAGE.format(code=code, width=size[0], height=size[1], zoom=size[1] / SIZE[1], headline=headline,
                       screen=screen, extra=extra.format())


def feature(shot, dark):
    """A block of the home page on a card. The dark tokens are DARK_TOKENS.
    The dark History card shows the capture of History in dark mode."""
    tokens = ""
    block = build.stage("en", shot).replace('src="/', 'src="')
    if dark:
        block = block.replace("shots/history-en.webp", "shots/history-dark-en.webp")
        tokens = ":root {" + DARK_TOKENS + "}"
    return FEATURE.format(tokens=tokens, width=FEATURE_SIZE[0], height=FEATURE_SIZE[1],
                          background="#161618" if dark else "#F5F5F7",
                          ring="rgba(255, 255, 255, 0.08)" if dark else "transparent",
                          block=block)


def main():
    for code, name in CARDS:
        shoot(card(code, SIZE), SITE / name, SIZE)
    shoot(card("en", GITHUB_SIZE), SITE / "og-github.png", GITHUB_SIZE)
    for dark, end in [(False, ""), (True, "-dark")]:
        shoot(card("en", SIZE, HERO_DARK if dark else HERO, dark), IMAGES / f"hero{end}.png", SIZE)
        for name, shot in FEATURES:
            shoot(feature(shot, dark), IMAGES / f"{name}{end}.png", FEATURE_SIZE, 1.5)


if __name__ == "__main__":
    main()
