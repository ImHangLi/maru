#!/usr/bin/env python3
"""Build the Maru site: python3 site/build.py

Reads src/strings/<lang>.json and PRIVACY.md, and writes the pages of every language into site/.
With --shots DIR it first converts the screenshots in DIR to 780 px wide WebP files in shots/.
"""

import html
import json
import re
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

# The App Store link of Maru. This one constant sets the link of every badge.
# It is a placeholder until Maru is on the App Store. Do not deploy the site with the placeholder.
PLACEHOLDER_STORE_URL = "https://apps.apple.com/app/id0000000000"
STORE_URL = PLACEHOLDER_STORE_URL

ORIGIN = "https://maru.day"
GITHUB = "https://github.com/ImHangLi/maru"
EMAIL = "hello@maru.day"
FEEDBACK_FORM = "https://tally.so/r/jadWkR"
# The language code (also the hreflang value) and the folder of each language. English is the default.
# A folder is a two-letter name, because ads and links carry it. The language code stays a correct language tag.
LANGS = [("en", ""), ("zh-Hans", "cn"), ("ja", "jp"), ("es", "es"), ("de", "de"), ("ko", "kr")]
PAGES = ["index.html", "faq.html", "privacy.html", "support.html"]
SHOTS = ["today", "history", "detail"]
SHOT_WIDTH = 780
# Apple asks for a badge height of 40 px or more on a screen.
PAGE_BADGE = 56
# Every icon comes from Hugeicons (free stroke set, version 4.3.5, MIT license). The stroke width is in style.css.
ICONS = {
    "github": "<path d=\"M10 20.5675C6.57143 21.7248 3.71429 20.5675 2 17\"/><path d=\"M10 22V18.7579C10 18.1596 10.1839 17.6396 10.4804 17.1699C10.6838 16.8476 10.5445 16.3904 10.1771 16.2894C7.13394 15.4528 5 14.1077 5 9.64606C5 8.48611 5.38005 7.39556 6.04811 6.4464C6.21437 6.21018 6.29749 6.09208 6.31748 5.9851C6.33746 5.87813 6.30272 5.73852 6.23322 5.45932C5.95038 4.32292 5.96871 3.11619 6.39322 2.02823C6.39322 2.02823 7.27042 1.74242 9.26698 2.98969C9.72282 3.27447 9.95075 3.41686 10.1515 3.44871C10.3522 3.48056 10.6206 3.41384 11.1573 3.28041C11.8913 3.09795 12.6476 3 13.5 3C14.3524 3 15.1087 3.09795 15.8427 3.28041C16.3794 3.41384 16.6478 3.48056 16.8485 3.44871C17.0493 3.41686 17.2772 3.27447 17.733 2.98969C19.7296 1.74242 20.6068 2.02823 20.6068 2.02823C21.0313 3.11619 21.0496 4.32292 20.7668 5.45932C20.6973 5.73852 20.6625 5.87813 20.6825 5.9851C20.7025 6.09207 20.7856 6.21019 20.9519 6.4464C21.6199 7.39556 22 8.48611 22 9.64606C22 14.1077 19.8661 15.4528 16.8229 16.2894C16.4555 16.3904 16.3162 16.8476 16.5196 17.1699C16.8161 17.6396 17 18.1596 17 18.7579V22\"/>",
    "globe": "<circle cx=\"12\" cy=\"12\" r=\"10\"/><path d=\"M8 12C8 18 12 22 12 22C12 22 16 18 16 12C16 6 12 2 12 2C12 2 8 6 8 12Z\"/><path d=\"M21 15H3\"/><path d=\"M21 9H3\"/>",
    "check": "<path d=\"M5 14L8.5 17.5L19 6.5\"/>",
    "close": "<path d=\"M18 6L6.00081 17.9992M17.9992 18L6 6.00085\"/>"
}

SITE = Path(__file__).resolve().parent
STRINGS = {code: json.loads((SITE / "src/strings" / f"{code}.json").read_text("utf-8")) for code, _ in LANGS}
FOLDER = dict(LANGS)
e = html.escape


def url(code, page):
    prefix = f"/{FOLDER[code]}" if FOLDER[code] else ""
    return f"{prefix}/" if page == "index.html" else f"{prefix}/{page}"


def webp_size(path):
    data = path.read_bytes()[:30]
    kind = data[12:16]
    if kind == b"VP8 ":
        width, height = struct.unpack("<HH", data[26:30])
        return width & 0x3FFF, height & 0x3FFF
    if kind == b"VP8L":
        bits = struct.unpack("<I", data[21:25])[0]
        return (bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1
    if kind == b"VP8X":
        return int.from_bytes(data[24:27], "little") + 1, int.from_bytes(data[27:30], "little") + 1
    raise ValueError(f"{path} is not a WebP file")


def import_shots(source):
    """Convert <name>.png and <name>-<lang>.png to WebP. Needs sips (macOS) and cwebp."""
    names = [(shot, code) for shot in SHOTS for code in [""] + [c for c, _ in LANGS[1:]]]
    (SITE / "shots").mkdir(exist_ok=True)
    for shot, code in names:
        stem = f"{shot}-{code}" if code else shot
        png = Path(source) / f"{stem}.png"
        if not png.exists():
            continue
        with tempfile.TemporaryDirectory() as tmp:
            small = Path(tmp) / "small.png"
            subprocess.run(["sips", "--resampleWidth", str(SHOT_WIDTH), str(png), "--out", str(small)],
                           check=True, capture_output=True)
            subprocess.run(["cwebp", "-quiet", "-q", "90", "-sharp_yuv", str(small), "-o",
                            str(SITE / "shots" / f"{stem}.webp")], check=True)
        print(f"shot {stem}")


def icon(name):
    return (f'<svg class="icon" viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" '
            f'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">{ICONS[name]}</svg>')


def cutout(code, name, extra=""):
    file = SITE / "shots" / f"{name}.webp"
    width, height = webp_size(file)
    alt = STRINGS[code]["shots"][name]["alt"]
    return (f'<img class="duo-{name}{extra}" src="/shots/{file.name}" width="{width}" height="{height}" decoding="async" '
            f'alt="{e(alt)}">')


def duo(code):
    """The widget and the reminder as one product picture, in a plain stack. The pictures are real cuts, and English on every page."""
    return f'<div class="duo">{cutout(code, "widget", " enter d2")}{cutout(code, "notification", " enter d3")}</div>'


def device(code, shot, eager=False):
    """An iPhone frame around a real screenshot. The language file wins, then the English file."""
    if shot == "duo":
        return duo(code)
    s = STRINGS[code]["shots"][shot]
    files = [SITE / "shots" / f"{shot}-{code}.webp", SITE / "shots" / f"{shot}.webp"]
    file = next((f for f in files if f.exists()), None)
    if file is None:
        return f'<div class="device"><div class="device-screen"><span>{e(s["label"])}</span></div></div>'
    width, height = webp_size(file)
    load = 'fetchpriority="high"' if eager else 'decoding="async"'
    return (f'<div class="device"><div class="device-screen"><img src="/shots/{file.name}" width="{width}" '
            f'height="{height}" {load} alt="{e(s["alt"])}"></div><span class="island" aria-hidden="true"></span></div>')


def badge(code, height):
    """Apple's "Download on the App Store" badge in the language of the page. The artwork is not changed."""
    svg = (SITE / "badges" / f"{code}.svg").read_text("utf-8")
    width, natural = (float(v) for v in re.search(r'width="([\d.]+)" height="([\d.]+)"', svg).groups())
    return (f'<a class="badge" href="{e(STORE_URL)}"><img src="/badges/{code}.svg" '
            f'width="{round(width * height / natural)}" height="{height}" alt="{e(STRINGS[code]["store"]["badge_alt"])}"></a>')


def phrases(text):
    """A "|" in a headline marks a place where the line can break. Each part stays in one piece,
    and enters as one unit when the page loads."""
    parts = text.split("|")
    return "".join(f'<span class="nb load d{i + 1}">{e(part.strip())}</span>{" " if part.endswith(" ") else ""}'
                   for i, part in enumerate(parts))


def layout(code, page, title, desc, main, head=""):
    s = STRINGS[code]
    f = s["footer"]
    here = ORIGIN + url(code, page)
    alternates = "".join(f'<link rel="alternate" hreflang="{c}" href="{ORIGIN}{url(c, page)}">\n' for c, _ in LANGS)
    banner = re.search(r"id(\d+)", STORE_URL)
    banner = (f'<meta name="apple-itunes-app" content="app-id={banner.group(1)}">\n'
              if banner and STORE_URL != PLACEHOLDER_STORE_URL else "")
    current = ' aria-current="page"'
    menu = "".join(
        f'<li><a href="{url(c, page)}" lang="{c}" hreflang="{c}"{current if c == code else ""}>{e(STRINGS[c]["name"])}'
        f'{icon("check") if c == code else ""}</a></li>'
        for c, _ in LANGS)
    languages = "".join(
        f'<li><a href="{url(c, page)}" lang="{c}" hreflang="{c}" data-suggest="{e(STRINGS[c]["suggest"])}" '
        f'data-close="{e(STRINGS[c]["close"])}"{current if c == code else ""}>{e(STRINGS[c]["name"])}</a></li>'
        for c, _ in LANGS)
    return f"""<!DOCTYPE html>
<html lang="{code}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{e(title)}</title>
<meta name="description" content="{e(desc)}">
<meta name="color-scheme" content="light dark">
<meta name="theme-color" content="#FFFFFF" media="(prefers-color-scheme: light)">
<meta name="theme-color" content="#000000" media="(prefers-color-scheme: dark)">
{banner}<link rel="canonical" href="{here}">
{alternates}<link rel="alternate" hreflang="x-default" href="{ORIGIN}{url("en", page)}">
<link rel="icon" href="/icon.png" type="image/png">
<link rel="apple-touch-icon" href="/icon.png">
<meta property="og:type" content="website">
<meta property="og:site_name" content="Maru">
<meta property="og:title" content="{e(title)}">
<meta property="og:description" content="{e(desc)}">
<meta property="og:url" content="{here}">
<meta property="og:image" content="{ORIGIN}/icon.png">
<meta name="twitter:card" content="summary">
{head}<script>if(!matchMedia("(prefers-reduced-motion: reduce)").matches)document.documentElement.classList.add("motion")</script>
<link rel="stylesheet" href="/style.css">
</head>
<body>
<a class="skip" href="#main">{e(s["skip"])}</a>
<header class="site-header"><div class="nav-inner">
<a class="brand" href="{url(code, "index.html")}"><img src="/icon.png" alt="" width="28" height="28"><span>Maru</span></a>
<nav class="nav-links" aria-label="{e(s["nav_label"])}">
<details class="lang-menu"><summary class="icon-btn" aria-label="{e(f["language"])}: {e(s["name"])}" data-tip="{e(f["language"])}">{icon("globe")}</summary><ul>{menu}</ul></details>
<a class="icon-btn" href="{GITHUB}" aria-label="{e(s["github"])}" data-tip="GitHub">{icon("github")}</a>
<a class="bar-cta" href="{e(STORE_URL)}">{e(s["store"]["download"])}</a>
</nav>
</div></header>
{main}
<footer class="site-footer">
<div class="footer-inner">
<ul class="footer-links"><li><a href="{url(code, "faq.html")}">{e(f["faq"])}</a></li><li><a href="{url(code, "support.html")}">{e(f["support"])}</a></li><li><a href="{url(code, "privacy.html")}">{e(f["privacy"])}</a></li><li><a href="{GITHUB}">{e(f["source"])}</a></li></ul>
<nav class="langs" aria-label="{e(f["language"])}"><ul>{languages}</ul></nav>
<p>{e(f["advice"])}</p>
</div>
</footer>
<template id="lang-hint"><aside class="lang-hint"><a href="{url(code, page)}">{e(s["suggest"])}</a><button type="button" class="icon-btn" aria-label="{e(s["close"])}">{icon("close")}</button></aside></template>
<script src="/site.js" defer></script>
</body>
</html>
"""


def home(code):
    s = STRINGS[code]
    h = s["home"]
    blocks = "".join(
        f'<article class="feature{" flip" if i % 2 else ""}" data-reveal><div class="feature-copy">'
        f'<h2 class="enter">{e(b["title"])}</h2><p class="lede enter d1">{e(b["text"])}</p></div>'
        f'<div class="feature-stage{"" if b["shot"] == "duo" else " enter d2"}">{device(code, b["shot"])}</div></article>\n'
        for i, b in enumerate(s["blocks"]))
    first, *rest = s["trust"]
    trust = f'<li><a href="{GITHUB}">{icon("github")}{e(first)}</a></li>' + "".join(f"<li>{e(t)}</li>" for t in rest)
    main = f"""<main id="main">
<section class="hero">
<div class="wrap hero-grid">
<div class="hero-copy">
<img class="hero-icon load" src="/icon.png" alt="" width="72" height="72">
<h1>{phrases(h["h1"])}</h1>
<p class="lede load d3">{e(h["lede"])}</p>
<div class="cta load d4">{badge(code, PAGE_BADGE)}</div>
</div>
<div class="hero-stage load-phone">{device(code, "today", eager=True)}</div>
</div>
</section>
<div class="wrap features">
{blocks}</div>
<section class="wrap" aria-labelledby="trust-title">
<div class="closer" data-reveal>
<h2 id="trust-title" class="sr">{e(s["trust_title"])}</h2>
<ul class="nots enter">{trust}</ul>
<p class="closer-links enter d1"><a href="{e(STORE_URL)}">{e(s["store"]["badge_alt"])}</a><a href="{url(code, "faq.html")}">{e(s["faq"]["h1"])}</a></p>
</div>
</section>
</main>"""
    return layout(code, "index.html", h["title"], h["desc"], main)


def links(code):
    return {"privacy": url(code, "privacy.html"), "faq": url(code, "faq.html"), "github": GITHUB}


def faq(code):
    s = STRINGS[code]["faq"]
    items = [(q, a.format(**links(code))) for q, a in s["items"]]
    body = "".join(f'<div class="qa"><h2>{e(q)}</h2><p>{a}</p></div>\n' for q, a in items)
    schema = {"@context": "https://schema.org", "@type": "FAQPage", "inLanguage": code, "mainEntity": [
        {"@type": "Question", "name": q, "acceptedAnswer": {"@type": "Answer", "text": re.sub(r"<[^>]+>", "", a)}}
        for q, a in items]}
    head = f'<script type="application/ld+json">{json.dumps(schema, ensure_ascii=False)}</script>\n'
    main = f'<main id="main" class="prose">\n<h1 class="load">{e(s["h1"])}</h1>\n<div class="load d1">\n{body}</div>\n</main>'
    return layout(code, "faq.html", s["title"], s["desc"], main, head)


def support(code):
    s = STRINGS[code]["support"]
    main = f"""<main id="main" class="prose">
<h1 class="load">{e(s["h1"])}</h1>
<div class="load d1">
<p class="lede">{e(s["lede"])}</p>
<div class="cards">
<article class="card"><h2>{e(s["email"])}</h2><p><a href="mailto:{EMAIL}">{EMAIL}</a></p></article>
<article class="card"><h2>{e(s["form"])}</h2><p><a href="{FEEDBACK_FORM}">{e(s["form_link"])}</a></p><p class="note">{e(s["form_note"])}</p></article>
</div>
<p>{s["note"].format(**links(code))}</p>
</div>
</main>"""
    return layout(code, "support.html", s["title"], s["desc"], main)


def inline(text):
    return re.sub(r"`([^`]+)`", r"<code>\1</code>", e(text, quote=False))


def policy(code):
    """PRIVACY.md as HTML. The text stays English. A language page gets its own headings."""
    headings = STRINGS[code]["privacy"]["headings"]
    out, depth = [], 0

    def close(to):
        nonlocal depth
        while depth > to:
            out.append("</li></ul>")
            depth -= 1

    text = (SITE.parent / "PRIVACY.md").read_text("utf-8").replace("This file", "This page")
    for line in text.splitlines():
        item = re.match(r"( *)- (.*)", line)
        if item:
            level = len(item.group(1)) // 2 + 1
            if level > depth:
                out.append("<ul>")
                depth += 1
            else:
                close(level)
                out.append("</li>")
            out.append(f"<li>{inline(item.group(2))}")
            continue
        close(0)
        if line.startswith("## "):
            title = line[3:]
            lang = "" if code == "en" else f' lang="{code}"'
            out.append(f"<h2{lang}>{e(title if code == 'en' else headings[title])}</h2>")
        elif line and not line.startswith("# "):
            out.append(f"<p>{inline(line)}</p>")
    close(0)
    return "\n".join(out)


def privacy(code):
    s = STRINGS[code]["privacy"]
    summary = "".join(f"<li>{e(line)}</li>" for line in s["summary"])
    binding = f'<p class="note">{e(s["binding"])}</p>\n' if s["binding"] else ""
    main = f"""<main id="main" class="prose">
<h1 class="load">{e(s["h1"])}</h1>
<div class="load d1">
<section class="card summary" aria-labelledby="summary-title"><h2 id="summary-title">{e(s["summary_title"])}</h2><ul>{summary}</ul></section>
{binding}<div class="policy" lang="en">
{policy(code)}
</div>
</div>
</main>"""
    return layout(code, "privacy.html", s["title"], s["desc"], main)


def sitemap():
    rows = []
    for page in PAGES:
        alternates = "".join(
            f'<xhtml:link rel="alternate" hreflang="{c}" href="{ORIGIN}{url(c, page)}"/>' for c, _ in LANGS)
        alternates += f'<xhtml:link rel="alternate" hreflang="x-default" href="{ORIGIN}{url("en", page)}"/>'
        rows += [f"  <url><loc>{ORIGIN}{url(code, page)}</loc>{alternates}</url>" for code, _ in LANGS]
    return ('<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" '
            'xmlns:xhtml="http://www.w3.org/1999/xhtml">\n' + "\n".join(rows) + "\n</urlset>\n")


def main():
    if len(sys.argv) == 3 and sys.argv[1] == "--shots":
        import_shots(sys.argv[2])
    render = {"index.html": home, "faq.html": faq, "privacy.html": privacy, "support.html": support}
    for code, folder in LANGS:
        (SITE / folder).mkdir(exist_ok=True)
        for page in PAGES:
            (SITE / folder / page).write_text(render[page](code), "utf-8")
    (SITE / "sitemap.xml").write_text(sitemap(), "utf-8")
    print(f"built {len(LANGS) * len(PAGES)} pages")
    if STORE_URL == PLACEHOLDER_STORE_URL:
        print("WARNING: STORE_URL is the placeholder. Every App Store badge has a link that does not work. Do not deploy.")

if __name__ == "__main__":
    main()
