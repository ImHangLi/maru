#!/usr/bin/env python3
"""Build the Maru site: python3 site/build.py

Reads src/strings/<lang>.json, src/mock/<lang>.json, and PRIVACY.md, and writes the pages of every language into site/.
With --shots DIR it first converts the screenshots in DIR to 780 px wide WebP files in shots/.
"""

import html
import json
import re
import struct
import subprocess
import sys
import tempfile
from math import isqrt
from pathlib import Path

import mock

# Is Maru in the App Store? While this is False, the site says "coming soon", shows no Apple badge,
# has no link to the App Store, and has no Smart App Banner. Set it to True on the day of the release, and build again.
RELEASED = True
# The App Store link of Maru. When RELEASED is True, this one constant sets the link of the badge, of the "Download"
# button in the top bar, and of the text link at the end of the home page. It also sets the Smart App Banner.
STORE_URL = "https://apps.apple.com/app/id6822159516"

ORIGIN = "https://maru.day"
EMAIL = "hello@maru.day"
FEEDBACK_FORM = "https://tally.so/r/jadWkR"
# The language code (also the hreflang value) and the folder of each language. English is the default.
# A folder is a two-letter name, because ads and links carry it. The language code stays a correct language tag.
LANGS = [("en", ""), ("zh-Hans", "cn"), ("ja", "jp"), ("es", "es"), ("de", "de"), ("ko", "kr")]
# Each page is the index file of its own folder, so its address ends with a slash and needs no redirect.
PAGES = ["index.html", "faq/index.html", "privacy/index.html", "support/index.html"]
# The addresses of the pages before the folders. _redirects sends them to the new addresses.
OLD_PAGES = {"faq.html": "faq/index.html", "privacy.html": "privacy/index.html", "support.html": "support/index.html"}
OG_LOCALE = {"en": "en_US", "zh-Hans": "zh_CN", "ja": "ja_JP", "es": "es_ES", "de": "de_DE", "ko": "ko_KR"}
# The picture of the site and the capture that it comes from, in <captures>/<lang>/.
SHOTS = {"today": "today", "items": "items", "history": "history-all", "alarm": "alarm", "family": "family"}
SHOT_WIDTH = 780
# The Lock Screen picture joins three captures of 2412 x 5244. The date comes from lock-date.png down to LOCK_DATE_END,
# and the clock and the wallpaper come from lock-clock.png. LOCK_CARD (left, top, right, bottom) is where the card of the
# Live Activity goes, over the reminder of those captures. Its rows start at LOCK_ACTIVITY_TOP in la.png, which shows the
# card on black. LOCK_CARD_FILL is the color of the card, and LOCK_CARD_RADIUS is its corner radius.
LOCK_W = 2412
LOCK_DATE_END = 660
LOCK_CARD = (84, 4015, 2328, 4535)
LOCK_ACTIVITY_TOP = 2450
LOCK_CARD_FILL = bytes.fromhex("1C1C1E")
LOCK_CARD_RADIUS = 144
# The jars of the photo block, from left to right. README.md names the source of each photo.
JARS = ["omega3", "vitd3", "magnesium"]
# Apple asks for a badge height of 40 px or more on a screen.
PAGE_BADGE = 56
# The devices that the line under the badge names. It must match the devices of the released app before a deploy.
# Possible values: "iphone", "ipad", "watch".
DEVICES = ["iphone", "ipad", "watch"]
# The icon and the product name of each device. Apple does not translate these names.
DEVICE_NAMES = {"iphone": ("phone", "iPhone"), "ipad": ("tablet", "iPad"), "watch": ("watch", "Apple Watch")}
# Every icon comes from Hugeicons (free stroke set, version 4.3.5, MIT license). The stroke width is in style.css.
ICONS = {
    "globe": "<circle cx=\"12\" cy=\"12\" r=\"10\"/><path d=\"M8 12C8 18 12 22 12 22C12 22 16 18 16 12C16 6 12 2 12 2C12 2 8 6 8 12Z\"/><path d=\"M21 15H3\"/><path d=\"M21 9H3\"/>",
    "check": "<path d=\"M5 14L8.5 17.5L19 6.5\"/>",
    "close": "<path d=\"M18 6L6.00081 17.9992M17.9992 18L6 6.00085\"/>",
    "phone": "<path d=\"M13.5 2H10.5C8.14298 2 6.96447 2 6.23223 2.73223C5.5 3.46447 5.5 4.64298 5.5 7V17C5.5 19.357 5.5 20.5355 6.23223 21.2678C6.96447 22 8.14298 22 10.5 22H13.5C15.857 22 17.0355 22 17.7678 21.2678C18.5 20.5355 18.5 19.357 18.5 17V7C18.5 4.64298 18.5 3.46447 17.7678 2.73223C17.0355 2 15.857 2 13.5 2Z\"/><path d=\"M12.125 19H12M12.25 19C12.25 19.1381 12.1381 19.25 12 19.25C11.8619 19.25 11.75 19.1381 11.75 19C11.75 18.8619 11.8619 18.75 12 18.75C12.1381 18.75 12.25 18.8619 12.25 19Z\"/>",
    "tablet": "<path d=\"M14.5 2H9.5C6.67157 2 5.25736 2 4.37868 2.87868C3.5 3.75736 3.5 5.17157 3.5 8V16C3.5 18.8284 3.5 20.2426 4.37868 21.1213C5.25736 22 6.67157 22 9.5 22H14.5C17.3284 22 18.7426 22 19.6213 21.1213C20.5 20.2426 20.5 18.8284 20.5 16V8C20.5 5.17157 20.5 3.75736 19.6213 2.87868C18.7426 2 17.3284 2 14.5 2Z\"/><path d=\"M12.125 19H12M12.25 19C12.25 19.1381 12.1381 19.25 12 19.25C11.8619 19.25 11.75 19.1381 11.75 19C11.75 18.8619 11.8619 18.75 12 18.75C12.1381 18.75 12.25 18.8619 12.25 19Z\"/>",
    "watch": "<path d=\"M7 11C7 9.11438 7 8.17157 7.58579 7.58579C8.17157 7 9.11438 7 11 7H13C14.8856 7 15.8284 7 16.4142 7.58579C17 8.17157 17 9.11438 17 11V13C17 14.8856 17 15.8284 16.4142 16.4142C15.8284 17 14.8856 17 13 17H11C9.11438 17 8.17157 17 7.58579 16.4142C7 15.8284 7 14.8856 7 13V11Z\"/><path d=\"M8.5 7C8.5 7 9.18904 5.66076 9.34422 4.00093C9.42833 3.10125 9.47038 2.6514 9.72393 2.39673C9.97748 2.14207 10.283 2.11215 10.8942 2.05231C11.217 2.0207 11.5863 2 12 2C12.4137 2 12.783 2.0207 13.1058 2.05231C13.717 2.11215 14.0225 2.14207 14.2761 2.39673C14.5296 2.6514 14.5717 3.10125 14.6558 4.00093C14.811 5.66076 15.5 7 15.5 7\"/><path d=\"M15.5 17C15.5 17 14.811 18.3392 14.6558 19.9991C14.5717 20.8988 14.5296 21.3486 14.2761 21.6033C14.0225 21.8579 13.717 21.8879 13.1058 21.9477C12.783 21.9793 12.4137 22 12 22C11.5863 22 11.217 21.9793 10.8942 21.9477C10.283 21.8879 9.97748 21.8579 9.72393 21.6033C9.47038 21.3486 9.42833 20.8988 9.34422 19.9991C9.18904 18.3392 8.5 17 8.5 17\"/>"
}

SITE = Path(__file__).resolve().parent
STRINGS = {code: json.loads((SITE / "src/strings" / f"{code}.json").read_text("utf-8")) for code, _ in LANGS}
# The comparison and topic pages. They are English only, so they have no hreflang alternates.
GUIDES = json.loads((SITE / "src/guides/en.json").read_text("utf-8"))
GUIDE_PAGES = [GUIDES["hub"]["path"] + "index.html"] + [g["path"] + "index.html" for g in GUIDES["pages"]]
FOLDER = dict(LANGS)
e = html.escape


def url(code, page):
    prefix = f"/{FOLDER[code]}" if FOLDER[code] else ""
    return f"{prefix}/{page.removesuffix('index.html')}"


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


def png_width(png):
    """The width of a PNG file."""
    return struct.unpack(">I", png.read_bytes()[16:20])[0]


def pixels(png):
    """The pixels of a capture as RGB bytes. Needs ffmpeg."""
    return subprocess.run(["ffmpeg", "-v", "error", "-i", str(png), "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
                          check=True, capture_output=True).stdout


def write_webp(png, name, width=SHOT_WIDTH):
    """Write a capture as a WebP file of the given width. Needs cwebp."""
    subprocess.run(["cwebp", "-quiet", "-q", "90", "-sharp_yuv", "-resize", str(width), "0", str(png), "-o",
                    str(SITE / "shots" / name)], check=True)


def import_lock(folder, code):
    """Make the Lock Screen picture: the Lock Screen with the card of the Live Activity in place of the reminder."""
    clock, date, activity = (pixels(folder / f"{name}.png") for name in ("lock-clock", "lock-date", "la"))
    line = LOCK_W * 3
    full = bytearray(date[:LOCK_DATE_END * line] + clock[LOCK_DATE_END * line:])
    left, top, right, bottom = LOCK_CARD
    for y in range(top, bottom):
        # The card rounds its corners: a row near an end of the card starts further in.
        edge = max(0, LOCK_CARD_RADIUS - (y - top), LOCK_CARD_RADIUS - (bottom - 1 - y))
        inset = LOCK_CARD_RADIUS - isqrt(max(0, LOCK_CARD_RADIUS ** 2 - edge ** 2)) if edge else 0
        source = LOCK_ACTIVITY_TOP + y - top
        cells = activity[source * line + (left + inset) * 3:source * line + (right - inset) * 3]
        # The capture has the card on black, so each channel is the brighter of the capture and the card color.
        full[y * line + (left + inset) * 3:y * line + (right - inset) * 3] = bytes(
            max(value, LOCK_CARD_FILL[i % 3]) for i, value in enumerate(cells))
    with tempfile.TemporaryDirectory() as tmp:
        png = Path(tmp) / "lock.png"
        subprocess.run(["ffmpeg", "-v", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{LOCK_W}x{len(full) // line}",
                        "-i", "-", str(png)], input=bytes(full), check=True)
        write_webp(png, f"lock-{code}.webp")


def import_shots(source):
    """Convert the captures of <source>/<lang>/ to WebP. Needs cwebp and ffmpeg. A language with no folder keeps its files."""
    (SITE / "shots").mkdir(exist_ok=True)
    for code, _ in LANGS:
        folder = Path(source) / code
        if not folder.is_dir():
            continue
        for shot, capture in SHOTS.items():
            write_webp(folder / f"{capture}.png", f"{shot}-{code}.webp")
        import_lock(folder, code)
        # The capture of the Watch is small, so it keeps its own width.
        write_webp(folder / "watch.png", f"watch-{code}.webp", png_width(folder / "watch.png"))
        print(f"shots {code}")


def icon(name):
    return (f'<svg class="icon" viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" '
            f'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">{ICONS[name]}</svg>')


def picture(code, shot, body, extra=""):
    """A code-drawn app component, read as one picture. Its text is in src/mock/<lang>.json."""
    alt = STRINGS[code]["shots"][shot]["alt"]
    return f'<div class="mock mock-{shot}{extra}" role="img" aria-label="{e(alt)}">{body}</div>'


def device(code, shot):
    """An iPhone frame around a real screenshot of the app in the language of the page."""
    file = SITE / "shots" / f"{shot}-{code}.webp"
    width, height = webp_size(file)
    return (f'<div class="device"><div class="device-screen"><img src="/shots/{file.name}" width="{width}" '
            f'height="{height}" loading="lazy" decoding="async" alt="{e(STRINGS[code]["shots"][shot]["alt"])}"></div>'
            f'<span class="island" aria-hidden="true"></span></div>')


def live_device(code):
    """The hero phone. With no script it is the picture of Today."""
    file = SITE / "shots" / f"today-{code}.webp"
    width, height = webp_size(file)
    # site.js adds the other screens and the buttons over the controls of the captures. It loads their pictures late.
    words = STRINGS[code]["phone"]
    labels = {name: words["show"].format(words[name]) for name in ("today", "items", "history")} | {"back": words["back"]}
    return (f'<div class="device" role="group" aria-label="{e(words["label"])}" data-shots="{code}" '
            f'data-labels="{e(json.dumps(labels, ensure_ascii=False))}"><div class="device-screen">'
            f'<img src="/shots/{file.name}" width="{width}" height="{height}" fetchpriority="high" draggable="false" '
            f'alt="{e(STRINGS[code]["shots"]["today"]["alt"])}"></div><span class="island" aria-hidden="true"></span></div>')


def watch(code):
    """An Apple Watch frame around a real capture of the Watch app."""
    file = SITE / "shots" / f"watch-{code}.webp"
    width, height = webp_size(file)
    return (f'<div class="watch"><img src="/shots/{file.name}" width="{width}" height="{height}" loading="lazy" '
            f'decoding="async" alt="{e(STRINGS[code]["shots"]["watch"]["alt"])}"></div>')


def jars(code):
    """Three supplement jars with made-up brand labels, cut out as the app cuts out a photo of an item."""
    imgs = "".join(
        f'<img src="/shots/jar-{name}.webp" width="{w}" height="{h}" loading="lazy" decoding="async" alt="">'
        for name, w, h in [(n, *webp_size(SITE / "shots" / f"jar-{n}.webp")) for n in JARS])
    return f'<div class="jars" role="img" aria-label="{e(STRINGS[code]["shots"]["photos"]["alt"])}">{imgs}</div>'


def stage(code, shot):
    """The picture of a block. The reminder block shows the reminder and the widget on a wallpaper."""
    if shot == "duo":
        t = mock.load(code)
        return (f'<div class="wallpaper">{picture(code, "notification", mock.reminder(t), " enter d2")}'
                f'{picture(code, "widget", mock.widget(t), " enter d3")}</div>')
    if shot == "photos":
        return jars(code)
    if shot == "watch":
        return watch(code)
    return device(code, shot)


def badge(code, height):
    """Apple's "Download on the App Store" badge in the language of the page. The artwork is not changed."""
    svg = (SITE / "badges" / f"{code}.svg").read_text("utf-8")
    width, natural = (float(v) for v in re.search(r'width="([\d.]+)" height="([\d.]+)"', svg).groups())
    return (f'<a class="badge" href="{e(STORE_URL)}"><img src="/badges/{code}.svg" '
            f'width="{round(width * height / natural)}" height="{height}" alt="{e(STRINGS[code]["store"]["badge_alt"])}"></a>')


def download(code):
    """The download unit of the hero. After the release: Apple's badge, and under it the devices that the app runs on.
    Before the release: one plain line with no Apple artwork, because Apple's badge is a call to get an app that is in the store."""
    s = STRINGS[code]["store"]
    devices = "".join(f'<li>{icon(DEVICE_NAMES[d][0])}{DEVICE_NAMES[d][1]}</li>' for d in DEVICES)
    first = badge(code, PAGE_BADGE) if RELEASED else f'<p class="soon">{e(s["soon"])}</p>'
    return (f'<div class="get load d3">{first}'
            f'<ul class="get-devices" aria-label="{e(s["devices"])}">{devices}</ul></div>')


def phrases(text, load=True):
    """A "|" in a headline marks a place where the line can break. Each part stays in one piece.
    In the hero headline, each part also enters as one unit when the page loads."""
    parts = text.split("|")
    if len(parts) == 1 and not load:
        return e(text)
    return "".join(f'<span class="nb{f" load d{i}" if load else ""}">{e(part.strip())}</span>{" " if part.endswith(" ") else ""}'
                   for i, part in enumerate(parts))


# Response headers for Cloudflare. Pictures change rarely, so a browser keeps them for a day and checks again
# after that. The style sheet and the script keep their names between releases, so they stay fresh for one hour.
# The pages keep the default: a browser asks each time. HSTS tells a browser to use HTTPS for this site.
HEADERS = """/*
  Strict-Transport-Security: max-age=31536000
  X-Content-Type-Options: nosniff
  Referrer-Policy: strict-origin-when-cross-origin

/shots/*
  Cache-Control: public, max-age=86400, stale-while-revalidate=604800

/badges/*
  Cache-Control: public, max-age=86400, stale-while-revalidate=604800

/icon.png
  Cache-Control: public, max-age=86400, stale-while-revalidate=604800

/style.css
  Cache-Control: public, max-age=3600, stale-while-revalidate=86400

/site.js
  Cache-Control: public, max-age=3600, stale-while-revalidate=86400
"""


def layout(code, page, title, desc, main, head="", langs=None):
    """langs: the languages that have this page. A link to another language goes to its home page."""
    s = STRINGS[code]
    f = s["footer"]
    here = ORIGIN + url(code, page)
    langs = langs or [c for c, _ in LANGS]

    def other(c):
        return page if c in langs else "index.html"

    alternates = "".join(f'<link rel="alternate" hreflang="{c}" href="{ORIGIN}{url(c, page)}">\n' for c in langs)
    if len(langs) > 1:
        alternates += f'<link rel="alternate" hreflang="x-default" href="{ORIGIN}{url("en", page)}">\n'
    else:
        alternates = ""
    banner = (f'<meta name="apple-itunes-app" content="app-id={re.search(r"id(\d+)", STORE_URL).group(1)}">\n'
              if RELEASED else "")
    # Google Search Console reads this tag on the home page to confirm the owner of the site. Keep it.
    if page == "index.html" and code == LANGS[0][0]:
        banner += '<meta name="google-site-verification" content="RS5MimbYtPjYD6RQrpYsM9gtvHPVW_mOC43pGs5eqRc">\n'
    cta = f'<a class="bar-cta" href="{e(STORE_URL)}">{e(s["store"]["download"])}</a>\n' if RELEASED else ""
    locales = "".join(f'<meta property="og:locale:alternate" content="{OG_LOCALE[c]}">\n' for c in langs if c != code)
    # The social preview card of the language (social.py), and its words for a screen reader.
    card = f'{ORIGIN}/og{"-" + FOLDER[code] if FOLDER[code] else ""}.png'
    card_alt = e(f'Maru. {" ".join(part.strip() for part in s["home"]["h1"].split("|"))} {s["shots"]["today"]["alt"]}')
    current = ' aria-current="page"'
    # Only the English footer links to the comparison pages, because they are English only.
    compare = f'<li><a href="{url(code, GUIDE_PAGES[0])}">{e(f["compare"])}</a></li>' if "compare" in f else ""
    menu = "".join(
        f'<li><a href="{url(c, other(c))}" lang="{c}" hreflang="{c}"{current if c == code else ""}>{e(STRINGS[c]["name"])}'
        f'{icon("check") if c == code else ""}</a></li>'
        for c, _ in LANGS)
    languages = "".join(
        f'<li><a href="{url(c, other(c))}" lang="{c}" hreflang="{c}" data-suggest="{e(STRINGS[c]["suggest"])}" '
        f'data-close="{e(STRINGS[c]["close"])}"{current if c == code else ""}>{e(STRINGS[c]["name"])}</a></li>'
        for c, _ in LANGS)
    return f"""<!DOCTYPE html>
<html lang="{code}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{e(title)}</title>
<meta name="description" content="{e(desc)}">
<meta name="color-scheme" content="light">
<meta name="theme-color" content="#FFFFFF">
{banner}<link rel="canonical" href="{here}">
{alternates}<link rel="icon" href="/icon.png" type="image/png">
<link rel="apple-touch-icon" href="/icon.png">
<meta property="og:type" content="website">
<meta property="og:site_name" content="Maru">
<meta property="og:title" content="{e(title)}">
<meta property="og:description" content="{e(desc)}">
<meta property="og:url" content="{here}">
<meta property="og:image" content="{card}">
<meta property="og:image:type" content="image/png">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta property="og:image:alt" content="{card_alt}">
<meta property="og:locale" content="{OG_LOCALE[code]}">
{locales}<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:image" content="{card}">
<meta name="twitter:image:alt" content="{card_alt}">
{head}<script>if(!matchMedia("(prefers-reduced-motion: reduce)").matches)document.documentElement.classList.add("motion")</script>
<link rel="stylesheet" href="/style.css">
</head>
<body>
<a class="skip" href="#main">{e(s["skip"])}</a>
<header class="site-header"><div class="nav-inner">
<a class="brand" href="{url(code, "index.html")}"><img src="/icon.png" alt="" width="28" height="28"><span>Maru</span></a>
<nav class="nav-links" aria-label="{e(s["nav_label"])}">
<details class="lang-menu"><summary class="icon-btn" aria-label="{e(f["language"])}: {e(s["name"])}" data-tip="{e(f["language"])}">{icon("globe")}</summary><ul>{menu}</ul></details>
{cta}</nav>
</div></header>
{main}
<footer class="site-footer">
<div class="footer-inner">
<ul class="footer-links"><li><a href="{url(code, "faq/index.html")}">{e(f["faq"])}</a></li><li><a href="{url(code, "support/index.html")}">{e(f["support"])}</a></li><li><a href="{url(code, "privacy/index.html")}">{e(f["privacy"])}</a></li>{compare}</ul>
<nav class="langs" aria-label="{e(f["language"])}"><ul>{languages}</ul></nav>
<p>{e(f["advice"])}</p>
</div>
</footer>
<template id="lang-hint"><aside class="lang-hint"><a href="{url(code, page)}">{e(s["suggest"])}</a><button type="button" class="icon-btn" aria-label="{e(s["close"])}">{icon("close")}</button></aside></template>
<script src="/site.js" defer></script>
</body>
</html>
"""


def mark(block):
    """The small mark of a block heading, as on the store screenshots: "PRO" or the system that a feature needs."""
    return f' <span class="mark">{e(block["mark"])}</span>' if "mark" in block else ""


def home(code):
    s = STRINGS[code]
    h = s["home"]
    blocks = "".join(
        f'<article class="feature{" flip" if i % 2 else ""}" data-reveal><div class="feature-copy">'
        f'<h2 class="enter">{phrases(b["title"], load=False)}{mark(b)}</h2><p class="lede enter d1">{e(b["text"])}</p></div>'
        f'<div class="feature-stage{"" if b["shot"] == "duo" else " enter d2"}">{stage(code, b["shot"])}</div></article>\n'
        for i, b in enumerate(s["blocks"]))
    store_link = f'<a href="{e(STORE_URL)}">{e(s["store"]["badge_alt"])}</a>' if RELEASED else ""
    trust = "".join(f"<li>{e(t)}</li>" for t in s["trust"])
    main = f"""<main id="main">
<section class="hero">
<div class="wrap hero-grid">
<div class="hero-copy">
<h1>{phrases(h["h1"])}</h1>
<p class="lede load d2">{e(h["lede"])}</p>
{download(code)}
</div>
<div class="hero-stage load-hero">{live_device(code)}</div>
</div>
</section>
<div class="wrap features">
{blocks}</div>
<section class="wrap" aria-labelledby="trust-title">
<div class="closer" data-reveal>
<h2 id="trust-title" class="sr">{e(s["trust_title"])}</h2>
<ul class="nots enter">{trust}</ul>
<p class="closer-links enter d1">{store_link}<a href="{url(code, "faq/index.html")}">{e(s["faq"]["h1"])}</a></p>
</div>
</section>
</main>"""
    return layout(code, "index.html", h["title"], h["desc"], main)


def links(code):
    return {"privacy": url(code, "privacy/index.html"), "faq": url(code, "faq/index.html")}


def faq(code):
    s = STRINGS[code]["faq"]
    items = [(q, a.format(**links(code))) for q, a in s["items"]]
    body = "".join(f'<div class="qa"><h2>{e(q)}</h2><p>{a}</p></div>\n' for q, a in items)
    schema = {"@context": "https://schema.org", "@type": "FAQPage", "inLanguage": code, "mainEntity": [
        {"@type": "Question", "name": q, "acceptedAnswer": {"@type": "Answer", "text": re.sub(r"<[^>]+>", "", a)}}
        for q, a in items]}
    head = f'<script type="application/ld+json">{json.dumps(schema, ensure_ascii=False)}</script>\n'
    main = f'<main id="main" class="prose">\n<h1 class="load">{e(s["h1"])}</h1>\n<div class="load d1">\n{body}</div>\n</main>'
    return layout(code, "faq/index.html", s["title"], s["desc"], main, head)


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
    return layout(code, "support/index.html", s["title"], s["desc"], main)


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
    return layout(code, "privacy/index.html", s["title"], s["desc"], main)


def guide_title(path):
    return next(g["h1"] for g in GUIDES["pages"] if g["path"] == path)


def guide_end(related=()):
    """The end of a comparison or topic page: the related pages, the store link, and the note about advice."""
    out = ""
    if related:
        items = "".join(f'<li><a href="/{r}">{e(guide_title(r))}</a></li>' for r in related)
        out += f'<h2>{e(GUIDES["related_title"])}</h2>\n<ul>{items}</ul>\n'
    store = f'<a href="{e(STORE_URL)}">{e(STRINGS["en"]["store"]["badge_alt"])}</a>' if RELEASED else ""
    out += f'<p class="closer-links guide-cta">{store}<a href="/faq/">{e(STRINGS["en"]["faq"]["h1"])}</a></p>\n'
    return out + f'<p class="note">{e(GUIDES["advice"])}</p>\n'


def compare_table(g):
    """Maru and one other app, one row for each fact. On a phone each row is a block with its own labels."""
    t = g["table"]
    maru, other = GUIDES["maru_label"], t["other"]
    rows = "".join(f'<tr><th scope="row">{e(label)}</th><td data-label="{e(maru)}">{e(a)}</td>'
                   f'<td data-label="{e(other)}">{e(b)}</td></tr>' for label, a, b in t["rows"])
    return (f'<table class="compare"><caption class="sr">{e(g["h1"])}</caption><thead><tr><td></td>'
            f'<th scope="col">{e(maru)}</th><th scope="col">{e(other)}</th></tr></thead><tbody>{rows}</tbody></table>\n')


def guide(g):
    """A comparison or topic page. Paragraphs and list items in src/guides/en.json may hold links, so they are not escaped."""
    body = ""
    checked = GUIDES["checked_note"].format(date=GUIDES["checked"])
    if g["group"] == "compare":
        body += f'<p class="note">{e(GUIDES["checked_short"].format(date=GUIDES["checked"]))}</p>\n'
    if "table" in g:
        body += compare_table(g)
    for sec in g["sections"]:
        body += f'<h2>{e(sec["h2"])}</h2>\n'
        if "ul" in sec:
            body += "<ul>" + "".join(f"<li>{item}</li>" for item in sec["ul"]) + "</ul>\n"
        body += "".join(f"<p>{para}</p>\n" for para in sec.get("p", []))
    if "sources" in g:
        items = "".join(f'<li><a href="{e(link)}">{e(label)}</a></li>' for label, link in g["sources"])
        body += (f'<section class="sources" aria-labelledby="sources-title"><h2 id="sources-title">'
                 f'{e(GUIDES["sources_title"])}</h2><p class="note">{e(checked)}</p><ul>{items}</ul></section>\n')
    body += guide_end(g.get("related", ()))
    main = f"""<main id="main" class="prose guide">
<h1 class="load">{e(g["h1"])}</h1>
<div class="load d1">
<p class="lede">{e(g["lede"])}</p>
{body}</div>
</main>"""
    return layout("en", g["path"] + "index.html", g["title"], g["desc"], main, langs=["en"])


def guide_hub():
    h = GUIDES["hub"]

    def group(name):
        return "".join(f'<li><a href="/{g["path"]}">{e(g["h1"])}</a><p>{e(g["card"])}</p></li>'
                       for g in GUIDES["pages"] if g["group"] == name)

    main = f"""<main id="main" class="prose guide">
<h1 class="load">{e(h["h1"])}</h1>
<div class="load d1">
<p class="lede">{e(h["lede"])}</p>
<h2>{e(h["compare_title"])}</h2>
<ul class="guide-list">{group("compare")}</ul>
<h2>{e(h["topics_title"])}</h2>
<ul class="guide-list">{group("topic")}</ul>
{guide_end()}</div>
</main>"""
    return layout("en", GUIDE_PAGES[0], h["title"], h["desc"], main, langs=["en"])


def sitemap():
    rows = []
    for page in PAGES:
        alternates = "".join(
            f'<xhtml:link rel="alternate" hreflang="{c}" href="{ORIGIN}{url(c, page)}"/>' for c, _ in LANGS)
        alternates += f'<xhtml:link rel="alternate" hreflang="x-default" href="{ORIGIN}{url("en", page)}"/>'
        rows += [f"  <url><loc>{ORIGIN}{url(code, page)}</loc>{alternates}</url>" for code, _ in LANGS]
    rows += [f"  <url><loc>{ORIGIN}{url('en', page)}</loc></url>" for page in GUIDE_PAGES]
    return ('<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" '
            'xmlns:xhtml="http://www.w3.org/1999/xhtml">\n' + "\n".join(rows) + "\n</urlset>\n")


def not_found():
    """The page for an address that does not exist. It is English, and it links to every language."""
    homes = "".join(f'<li><a href="{url(c, "index.html")}" lang="{c}" hreflang="{c}">{e(STRINGS[c]["name"])}</a></li>' for c, _ in LANGS)
    main = f"""<main id="main" class="prose">
<h1 class="load">Page not found</h1>
<div class="load d1">
<p class="lede">This address has no page. Go to the home page of Maru.</p>
<ul>{homes}</ul>
</div>
</main>"""
    page = layout("en", "index.html", "Maru: Page not found", "This address has no page.", main,
                  '<meta name="robots" content="noindex">\n')
    return re.sub(r'<link rel="(canonical|alternate)"[^>]*>\n', "", page)


def redirects():
    rows = [f"/compare.html {url('en', GUIDE_PAGES[0])} 301", "/us / 301", "/us/* /:splat 301"]
    for code, folder in LANGS:
        prefix = f"/{folder}" if folder else ""
        rows += [f"{prefix}/{old} {url(code, new)} 301" for old, new in OLD_PAGES.items()]
    for old, new in [("zh-hans", "cn"), ("ja", "jp"), ("ko", "kr")]:
        rows += [f"/{old} /{new}/ 301", f"/{old}/* /{new}/:splat 301"]
    return "\n".join(rows) + "\n"


def llms():
    state = "It is in the App Store." if RELEASED else "It is not in the App Store yet."
    devices = ", ".join(DEVICE_NAMES[d][1] for d in DEVICES)
    guides = "\n".join(f"- [{g['h1']}]({ORIGIN}/{g['path']}): {g['card']}" for g in GUIDES["pages"])
    languages = "\n".join(f"- {name}: {ORIGIN}{url(code, 'index.html')}" for code, name in [
        ("en", "English"), ("zh-Hans", "Simplified Chinese"), ("ja", "Japanese"), ("es", "Spanish"), ("de", "German"), ("ko", "Korean")])
    return f"""# Maru

> Maru is a small app for daily vitamins, supplements, and simple medication schedules. It reminds you at the times you choose, shows what to take now, and keeps a record. {state}

Facts:
- Runs on: {devices}.
- "Did I take it today?" One look at your records, and you know.
- Free to download. Reminders, alarms, records, History, widgets, CSV export, and backup are free, with no limit on items. No account and no ads.
- Maru Pro is optional: "Next Dose on Lock Screen" (a Live Activity), the Apple Watch app, PDF reports, 30-day counts, Family (people and pets on one iPhone or iPad), app icons, reminder sounds, and app colors. A yearly plan with a 7-day free trial, or a one-time lifetime purchase. Family Sharing is on.
- Items and records stay on the iPhone or iPad. With Maru Pro, the iPhone sends the list of today to the user's own paired Apple Watch. Optional usage statistics never include names, doses, or times.
- Today screen: record a dose with one tap.
- Local reminders at the times you choose, with an optional "Remind Again" of up to 12 more reminders for a dose. On iOS 26 or later, an item can have a free alarm that rings in Silent mode and Focus, like the Clock app.
- Record from the reminder: "Taken", "Skip", and "Remind in 10 min" for one item, and "Take All" and "Skip All" for several items.
- Schedules: every day, every other day, every few days (every 3 to 30 days), or days on and days off (for example 21 on and 7 off). As-needed items have no reminders.
- History with undo and correction. No streaks and no penalties. Record export (CSV), backup, and restore. With Maru Pro, the 30-day counts of each item, and a medication list and a summary as PDF. The user chooses where each file goes.
- Home Screen and Lock Screen widgets, with "Next Dose" and "Last Dose".
- Item photos: take or choose a photo of a bottle as the item icon. Maru can remove the background on the device, and it never sends the photo.
- Languages: English, Simplified Chinese, Japanese, Spanish, German, and Korean.
- Maru does not track stock, give medical advice, or pick a dose or a time for you.
- Each iPhone or iPad keeps its own data. Maru has no shared profiles and no sync between devices.

Pages:
- [FAQ]({ORIGIN}/faq/): short answers.
- [Privacy]({ORIGIN}/privacy/): what the app stores and what it does not do.
- [Support]({ORIGIN}/support/): hello@maru.day and the feedback form.
- [Compare]({ORIGIN}/{GUIDES["hub"]["path"]}): Maru and other pill reminder apps, in English.

Comparisons and guides (English):
{guides}

Languages:
{languages}
"""


def main():
    if len(sys.argv) == 3 and sys.argv[1] == "--shots":
        import_shots(sys.argv[2])
    render = {"index.html": home, "faq/index.html": faq, "privacy/index.html": privacy, "support/index.html": support}
    for code, folder in LANGS:
        for page in PAGES:
            file = SITE / folder / page
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_text(render[page](code), "utf-8")
    for page, render_guide in zip(GUIDE_PAGES, [guide_hub] + [lambda g=g: guide(g) for g in GUIDES["pages"]]):
        file = SITE / page
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text(render_guide(), "utf-8")
    (SITE / "404.html").write_text(not_found(), "utf-8")
    (SITE / "sitemap.xml").write_text(sitemap(), "utf-8")
    (SITE / "_redirects").write_text(redirects(), "utf-8")
    (SITE / "_headers").write_text(HEADERS, "utf-8")
    (SITE / "llms.txt").write_text(llms(), "utf-8")
    print(f"built {len(LANGS) * len(PAGES) + len(GUIDE_PAGES)} pages")


if __name__ == "__main__":
    main()
