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
from urllib.parse import quote

# The App Store link of Maru. Leave it empty until Maru is on the App Store, then build again.
# Example: "https://apps.apple.com/app/id0000000000"
STORE_URL = ""

ORIGIN = "https://maru.day"
GITHUB = "https://github.com/ImHangLi/maru"
EMAIL = "hello@maru.day"
FEEDBACK_FORM = "https://tally.so/r/jadWkR"
# The language code (also the hreflang value) and the folder of each language. English is the default.
LANGS = [("en", ""), ("zh-Hans", "zh-hans"), ("ja", "ja"), ("es", "es"), ("de", "de"), ("ko", "ko")]
PAGES = ["index.html", "faq.html", "privacy.html", "support.html"]
SHOTS = ["today", "reminder", "history", "widget", "detail"]
SHOT_WIDTH = 780

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


def device(code, shot, eager=False):
    """An iPhone frame around a real screenshot. The language file wins, then the English file."""
    s = STRINGS[code]["shots"][shot]
    files = [SITE / "shots" / f"{shot}-{code}.webp", SITE / "shots" / f"{shot}.webp"]
    file = next((f for f in files if f.exists()), None)
    if file is None:
        return f'<div class="device"><div class="device-screen"><span>{e(s["label"])}</span></div></div>'
    width, height = webp_size(file)
    load = 'loading="eager" fetchpriority="high"' if eager else 'loading="lazy" decoding="async"'
    return (f'<div class="device"><div class="device-screen"><img src="/shots/{file.name}" width="{width}" '
            f'height="{height}" {load} alt="{e(s["alt"])}"></div><span class="island" aria-hidden="true"></span></div>')


def store_button(code):
    s = STRINGS[code]["store"]
    if STORE_URL:
        svg = (SITE / "badges" / f"{code}.svg").read_text("utf-8")
        width, height = (float(v) for v in re.search(r'width="([\d.]+)" height="([\d.]+)"', svg).groups())
        return (f'<div class="cta"><a class="badge" href="{e(STORE_URL)}"><img src="/badges/{code}.svg" '
                f'width="{round(width * 56 / height)}" height="56" alt="{e(s["badge_alt"])}"></a></div>')
    mail = f"mailto:{EMAIL}?subject={quote(s['notify_subject'])}"
    return (f'<div class="cta"><span class="store" role="img" aria-label="{e(s["soon_label"])}">'
            f'<small>{e(s["soon_small"])}</small><strong>App Store</strong></span>'
            f'<a class="notify" href="{mail}">{e(s["notify"])}</a></div>')


def nav_cta(code):
    s = STRINGS[code]["store"]
    if STORE_URL:
        return f'<a class="nav-cta" href="{e(STORE_URL)}">{e(s["nav_download"])}</a>'
    mail = f"mailto:{EMAIL}?subject={quote(s['notify_subject'])}"
    return f'<a class="nav-cta" href="{mail}">{e(s["nav_notify"])}</a>'


def phrases(text):
    """A "|" in a headline marks a place where the line can break. Each part stays in one piece."""
    return "".join(f'<span class="nb">{e(part)}</span>' for part in text.split("|"))


def layout(code, page, title, desc, main, head=""):
    s = STRINGS[code]
    f = s["footer"]
    here = ORIGIN + url(code, page)
    alternates = "".join(f'<link rel="alternate" hreflang="{c}" href="{ORIGIN}{url(c, page)}">\n' for c, _ in LANGS)
    banner = re.search(r"id(\d+)", STORE_URL)
    banner = f'<meta name="apple-itunes-app" content="app-id={banner.group(1)}">\n' if banner else ""
    current = ' aria-current="page"'
    languages = "".join(
        f'<li><a href="{url(c, page)}" lang="{c}" hreflang="{c}" data-suggest="{e(STRINGS[c]["suggest"])}" '
        f'data-close="{e(STRINGS[c]["close"])}"{current if c == code else ""}>{e(STRINGS[c]["name"])}</a></li>'
        for c, _ in LANGS)
    return f"""<!doctype html>
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
{head}<script>document.documentElement.classList.add('js')</script>
<link rel="stylesheet" href="/style.css">
</head>
<body>
<a class="skip" href="#main">{e(s["skip"])}</a>
<header class="site-header"><div class="nav-inner"><a class="brand" href="{url(code, "index.html")}"><img src="/icon.png" alt="" width="28" height="28"><span>Maru</span></a><nav class="nav-links" aria-label="{e(s["nav_label"])}"><a href="{url(code, "faq.html")}"{current if page == "faq.html" else ""}>{e(f["faq"])}</a>{nav_cta(code)}</nav></div></header>
{main}
<footer class="site-footer">
<div class="footer-inner">
<nav class="footer-links" aria-label="Maru"><a href="{url(code, "faq.html")}">{e(f["faq"])}</a><a href="{url(code, "support.html")}">{e(f["support"])}</a><a href="{url(code, "privacy.html")}">{e(f["privacy"])}</a><a href="{GITHUB}">{e(f["source"])}</a></nav>
<nav class="langs" aria-label="{e(f["language"])}"><ul>{languages}</ul></nav>
<p>{e(f["advice"])}</p>
</div>
</footer>
<script src="/site.js" defer></script>
</body>
</html>
"""


def home(code):
    s = STRINGS[code]
    h = s["home"]
    blocks = "".join(
        f'<article class="feature{" flip" if i % 2 else ""}" data-reveal="large"><div class="feature-copy">'
        f'<h2>{e(b["title"])}</h2><p class="lede">{e(b["text"])}</p></div>'
        f'<div class="feature-stage">{device(code, b["shot"])}</div></article>\n'
        for i, b in enumerate(s["blocks"]))
    trust = "".join(f"<li>{e(t)}</li>" for t in s["trust"])
    main = f"""<main id="main">
<section class="hero">
<div class="wrap hero-grid">
<div class="hero-copy">
<img class="hero-icon" src="/icon.png" alt="" width="72" height="72">
<h1>{phrases(h["h1"])}</h1>
<p class="lede">{e(h["lede"])}</p>
{store_button(code)}
</div>
<div class="hero-stage">{device(code, "today", eager=True)}</div>
</div>
</section>
<section class="wrap features">
{blocks}</section>
<section class="wrap" aria-labelledby="trust-title">
<div class="closer" data-reveal="large">
<h2 id="trust-title" class="sr">{e(s["trust_title"])}</h2>
<ul class="nots">{trust}</ul>
{store_button(code)}
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
    main = f'<main id="main" class="prose">\n<h1>{e(s["h1"])}</h1>\n{body}</main>'
    return layout(code, "faq.html", s["title"], s["desc"], main, head)


def support(code):
    s = STRINGS[code]["support"]
    main = f"""<main id="main" class="prose">
<h1>{e(s["h1"])}</h1>
<p class="lede">{e(s["lede"])}</p>
<div class="cards">
<article class="card"><h2>{e(s["email"])}</h2><p><a href="mailto:{EMAIL}">{EMAIL}</a></p></article>
<article class="card"><h2>{e(s["form"])}</h2><p><a href="{FEEDBACK_FORM}">{e(s["form_link"])}</a></p><p class="note">{e(s["form_note"])}</p></article>
</div>
<p>{s["note"].format(**links(code))}</p>
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
<h1>{e(s["h1"])}</h1>
<section class="card summary" aria-labelledby="summary-title"><h2 id="summary-title">{e(s["summary_title"])}</h2><ul>{summary}</ul></section>
{binding}<div class="policy" lang="en">
{policy(code)}
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


if __name__ == "__main__":
    main()
