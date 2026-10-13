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
from pathlib import Path

import mock

# Is Maru in the App Store? While this is False, the site says "coming soon", shows no Apple badge,
# has no link to the App Store, and has no Smart App Banner. Set it to True on the day of the release, and build again.
RELEASED = False
# The App Store link of Maru. When RELEASED is True, this one constant sets the link of the badge, of the "Download"
# button in the top bar, and of the text link at the end of the home page. It also sets the Smart App Banner.
STORE_URL = "https://apps.apple.com/app/id6822159516"

ORIGIN = "https://maru.day"
GITHUB = "https://github.com/ImHangLi/maru"
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
SHOTS = ["today", "history", "detail", "items"]
SHOT_WIDTH = 780
# A capture of an iPhone 17 Pro simulator, and the rows of Today in it. The layout is the same in every language.
CAPTURE_W, CAPTURE_H = 1206, 2622
APP_BG = bytes.fromhex("F2F2F7")
# The status bar starts at TODAY_STATUS, the toolbar buttons at TODAY_TOOLBAR, and the title at TODAY_TITLE.
# TODAY_SEAM is an empty row between the date and the first group. The tab bar starts at TODAY_TAB_BAR.
TODAY_STATUS, TODAY_TOOLBAR, TODAY_TITLE, TODAY_SEAM, TODAY_TAB_BAR = 60, 150, 370, 570, 2371
# How far the shadow of a glass shape reaches: to each side, and below.
GLASS_SHADOW = (7, 30)
# The top of the screen hides the list that scrolls under it: the background is solid down to the first row, and it
# fades out at the second row. The title is below the second row when the list is at its top.
TODAY_EDGE = (300, 350)
# Empty rows after the last group, so the last row comes to rest above the tab bar with a gap.
TODAY_END_SPACE = 45
# A sheet of the app (Settings, Add Item) in a capture. Its top edge is at SHEET_TOP. Its bar is solid down to the first
# row of SHEET_EDGE and fades out at the second row. The first row of the form is below it when the form is at its top.
SHEETS = ["settings", "add"]
SHEET_TOP = 186
SHEET_EDGE = (400, 430)
# The form comes from the first capture down to SHEET_SEAM, and from the second capture after it. The last card of
# the form ends above SHEET_LIMIT in the second capture. A debug build has more rows after it, and the site leaves them out.
SHEET_SEAM, SHEET_LIMIT = 2300, 2540
SHEET_END_SPACE = 105
# The jars of the photo block, from left to right. README.md names the source of each photo.
JARS = ["omega3", "vitd3", "magnesium"]
# Apple asks for a badge height of 40 px or more on a screen.
PAGE_BADGE = 56
# The devices that the line under the badge names. It must match the devices of the released app before a deploy.
# Possible values: "iphone", "ipad", "watch".
DEVICES = ["iphone", "ipad"]
# The icon and the product name of each device. Apple does not translate these names.
DEVICE_NAMES = {"iphone": ("phone", "iPhone"), "ipad": ("tablet", "iPad"), "watch": ("watch", "Apple Watch")}
# Every icon comes from Hugeicons (free stroke set, version 4.3.5, MIT license). The stroke width is in style.css.
ICONS = {
    "github": "<path d=\"M10 20.5675C6.57143 21.7248 3.71429 20.5675 2 17\"/><path d=\"M10 22V18.7579C10 18.1596 10.1839 17.6396 10.4804 17.1699C10.6838 16.8476 10.5445 16.3904 10.1771 16.2894C7.13394 15.4528 5 14.1077 5 9.64606C5 8.48611 5.38005 7.39556 6.04811 6.4464C6.21437 6.21018 6.29749 6.09208 6.31748 5.9851C6.33746 5.87813 6.30272 5.73852 6.23322 5.45932C5.95038 4.32292 5.96871 3.11619 6.39322 2.02823C6.39322 2.02823 7.27042 1.74242 9.26698 2.98969C9.72282 3.27447 9.95075 3.41686 10.1515 3.44871C10.3522 3.48056 10.6206 3.41384 11.1573 3.28041C11.8913 3.09795 12.6476 3 13.5 3C14.3524 3 15.1087 3.09795 15.8427 3.28041C16.3794 3.41384 16.6478 3.48056 16.8485 3.44871C17.0493 3.41686 17.2772 3.27447 17.733 2.98969C19.7296 1.74242 20.6068 2.02823 20.6068 2.02823C21.0313 3.11619 21.0496 4.32292 20.7668 5.45932C20.6973 5.73852 20.6625 5.87813 20.6825 5.9851C20.7025 6.09207 20.7856 6.21019 20.9519 6.4464C21.6199 7.39556 22 8.48611 22 9.64606C22 14.1077 19.8661 15.4528 16.8229 16.2894C16.4555 16.3904 16.3162 16.8476 16.5196 17.1699C16.8161 17.6396 17 18.1596 17 18.7579V22\"/>",
    "globe": "<circle cx=\"12\" cy=\"12\" r=\"10\"/><path d=\"M8 12C8 18 12 22 12 22C12 22 16 18 16 12C16 6 12 2 12 2C12 2 8 6 8 12Z\"/><path d=\"M21 15H3\"/><path d=\"M21 9H3\"/>",
    "check": "<path d=\"M5 14L8.5 17.5L19 6.5\"/>",
    "close": "<path d=\"M18 6L6.00081 17.9992M17.9992 18L6 6.00085\"/>",
    "phone": "<path d=\"M13.5 2H10.5C8.14298 2 6.96447 2 6.23223 2.73223C5.5 3.46447 5.5 4.64298 5.5 7V17C5.5 19.357 5.5 20.5355 6.23223 21.2678C6.96447 22 8.14298 22 10.5 22H13.5C15.857 22 17.0355 22 17.7678 21.2678C18.5 20.5355 18.5 19.357 18.5 17V7C18.5 4.64298 18.5 3.46447 17.7678 2.73223C17.0355 2 15.857 2 13.5 2Z\"/><path d=\"M12.125 19H12M12.25 19C12.25 19.1381 12.1381 19.25 12 19.25C11.8619 19.25 11.75 19.1381 11.75 19C11.75 18.8619 11.8619 18.75 12 18.75C12.1381 18.75 12.25 18.8619 12.25 19Z\"/>",
    "tablet": "<path d=\"M14.5 2H9.5C6.67157 2 5.25736 2 4.37868 2.87868C3.5 3.75736 3.5 5.17157 3.5 8V16C3.5 18.8284 3.5 20.2426 4.37868 21.1213C5.25736 22 6.67157 22 9.5 22H14.5C17.3284 22 18.7426 22 19.6213 21.1213C20.5 20.2426 20.5 18.8284 20.5 16V8C20.5 5.17157 20.5 3.75736 19.6213 2.87868C18.7426 2 17.3284 2 14.5 2Z\"/><path d=\"M12.125 19H12M12.25 19C12.25 19.1381 12.1381 19.25 12 19.25C11.8619 19.25 11.75 19.1381 11.75 19C11.75 18.8619 11.8619 18.75 12 18.75C12.1381 18.75 12.25 18.8619 12.25 19Z\"/>",
    "watch": "<path d=\"M7 11C7 9.11438 7 8.17157 7.58579 7.58579C8.17157 7 9.11438 7 11 7H13C14.8856 7 15.8284 7 16.4142 7.58579C17 8.17157 17 9.11438 17 11V13C17 14.8856 17 15.8284 16.4142 16.4142C15.8284 17 14.8856 17 13 17H11C9.11438 17 8.17157 17 7.58579 16.4142C7 15.8284 7 14.8856 7 13V11Z\"/><path d=\"M8.5 7C8.5 7 9.18904 5.66076 9.34422 4.00093C9.42833 3.10125 9.47038 2.6514 9.72393 2.39673C9.97748 2.14207 10.283 2.11215 10.8942 2.05231C11.217 2.0207 11.5863 2 12 2C12.4137 2 12.783 2.0207 13.1058 2.05231C13.717 2.11215 14.0225 2.14207 14.2761 2.39673C14.5296 2.6514 14.5717 3.10125 14.6558 4.00093C14.811 5.66076 15.5 7 15.5 7\"/><path d=\"M15.5 17C15.5 17 14.811 18.3392 14.6558 19.9991C14.5717 20.8988 14.5296 21.3486 14.2761 21.6033C14.0225 21.8579 13.717 21.8879 13.1058 21.9477C12.783 21.9793 12.4137 22 12 22C11.5863 22 11.217 21.9793 10.8942 21.9477C10.283 21.8879 9.97748 21.8579 9.72393 21.6033C9.47038 21.3486 9.42833 20.8988 9.34422 19.9991C9.18904 18.3392 8.5 17 8.5 17\"/>"
}

SITE = Path(__file__).resolve().parent
STRINGS = {code: json.loads((SITE / "src/strings" / f"{code}.json").read_text("utf-8")) for code, _ in LANGS}
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


def pixels(png):
    """The pixels of a capture as RGB bytes. Needs ffmpeg."""
    return subprocess.run(["ffmpeg", "-v", "error", "-i", str(png), "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
                          check=True, capture_output=True).stdout


def write_webp(data, mode, height, name):
    """Write raw pixels of the capture width as a WebP file of SHOT_WIDTH. Needs ffmpeg and cwebp."""
    with tempfile.TemporaryDirectory() as tmp:
        png = Path(tmp) / "full.png"
        subprocess.run(["ffmpeg", "-v", "error", "-f", "rawvideo", "-pix_fmt", mode, "-s", f"{CAPTURE_W}x{height}",
                        "-i", "-", str(png)], input=bytes(data), check=True)
        subprocess.run(["cwebp", "-quiet", "-q", "90", "-sharp_yuv", "-resize", str(SHOT_WIDTH), "0", str(png), "-o",
                        str(SITE / "shots" / name)], check=True)


def import_today(source, code):
    """Make the two pictures of the hero phone from two captures of Today: the list at its top (today-<lang>.png) and
    the list at its end (today-end-<lang>.png). today-<lang>.webp is the full list with no bars, and
    today-bars-<lang>.webp is the status bar, the toolbar buttons, and the tab bar. The top of it hides the list, and the rest is clear."""
    top, end = pixels(Path(source) / f"today-{code}.png"), pixels(Path(source) / f"today-end-{code}.png")
    line = CAPTURE_W * 3
    blank = APP_BG * CAPTURE_W

    def row(buf, y):
        return buf[y * line:(y + 1) * line]

    # How far the list moved between the two captures.
    shift = next(d for d in range(1, TODAY_TITLE) if all(row(top, y) == row(end, y - d) for y in range(700, 2100, 100)))
    if row(top, TODAY_SEAM) != blank or row(end, TODAY_SEAM - shift) != blank or row(end, TODAY_TAB_BAR - 1) != blank:
        raise ValueError(f"today-{code}: a cut is not on the background")
    # The list: the title from the first capture, the rows from the second, and the space that lets the last row
    # scroll above the tab bar, as in the app.
    full = blank * TODAY_TITLE + top[TODAY_TITLE * line:TODAY_SEAM * line] \
        + end[(TODAY_SEAM - shift) * line:TODAY_TAB_BAR * line]
    height = CAPTURE_H + shift + TODAY_END_SPACE
    full += blank * (height - len(full) // line)
    write_webp(full, "rgb24", height, f"today-{code}.webp")

    # The bars. A glass shape is opaque. Around it, a pixel that is a darker background is a shadow or the edge of a
    # black glyph, so it becomes black with the same strength. That keeps the look over the rows that scroll under it.
    bars = bytearray(CAPTURE_W * CAPTURE_H * 4)

    def edge(y):
        """How much of the background the top of the screen has at row y: 1 is solid, and 0 is clear."""
        t = min(1, max(0, (TODAY_EDGE[1] - y) / (TODAY_EDGE[1] - TODAY_EDGE[0])))
        return t * t * (3 - 2 * t)

    for y in range(TODAY_EDGE[1]):
        bars[y * CAPTURE_W * 4:(y + 1) * CAPTURE_W * 4] = (APP_BG + bytes([round(255 * edge(y))])) * CAPTURE_W
    areas = [(top, TODAY_STATUS, TODAY_TOOLBAR, 0, CAPTURE_W), (top, TODAY_TOOLBAR, TODAY_TITLE, 0, CAPTURE_W // 2),
             (top, TODAY_TOOLBAR, TODAY_TITLE, CAPTURE_W // 2, CAPTURE_W), (end, TODAY_TAB_BAR, CAPTURE_H, 0, CAPTURE_W)]
    for index, (buf, y0, y1, x0, x1) in enumerate(areas):
        marks = [(x, y) for y in range(y0, y1) for x in range(x0, x1)
                 if buf[y * line + x * 3:y * line + x * 3 + 3] != APP_BG]
        xs, ys = [x for x, _ in marks], [y for _, y in marks]
        # The glass is a capsule. Its shadow reaches GLASS_SHADOW pixels to each side and below. The status bar has none.
        side, below = (0, 0) if index == 0 else GLASS_SHADOW
        left, right, up, radius = min(xs) + side, max(xs) - side, min(ys), (max(ys) - below - min(ys)) / 2
        for x, y in marks:
            r, g, b = buf[y * line + x * 3:y * line + x * 3 + 3]
            nearest = min(max(x, left + radius), right - radius)
            glass = index > 0 and (x - nearest) ** 2 + (y - up - radius) ** 2 <= radius ** 2
            shade = r / APP_BG[0]
            if not glass and r == g and shade < 1 and abs(b - APP_BG[2] * shade) < 4:
                # The shadow lies over the background of the top of the screen, where that background is.
                under, dark = edge(y), 1 - shade
                cover = dark + under * shade
                r, g, b = (round(c * under * shade / cover) for c in APP_BG)
                alpha = round(255 * cover)
            else:
                alpha = 255
            bars[(y * CAPTURE_W + x) * 4:(y * CAPTURE_W + x) * 4 + 4] = bytes((r, g, b, alpha))
    write_webp(bars, "rgba", CAPTURE_H, f"today-bars-{code}.webp")


def import_sheet(source, name, code):
    """Make the two pictures of a sheet of the hero phone from two captures: the form at its top (<name>-<lang>.png)
    and the form scrolled down (<name>-end-<lang>.png). <name>-<lang>.webp is the full form with no bar, and
    <name>-bar-<lang>.webp is the bar of the sheet with a soft lower edge. Both start at the top edge of the sheet."""
    top, end = pixels(Path(source) / f"{name}-{code}.png"), pixels(Path(source) / f"{name}-end-{code}.png")
    line = CAPTURE_W * 3
    blank = APP_BG * CAPTURE_W

    def row(buf, y):
        return buf[y * line:(y + 1) * line]

    shift = next(d for d in range(1, SHEET_SEAM - SHEET_EDGE[1])
                 if all(row(top, y) == row(end, y - d) for y in range(SHEET_SEAM - 400, SHEET_SEAM + 1, 50)))
    if any(row(top, y) != blank for y in range(*SHEET_EDGE)):
        raise ValueError(f"{name}-{code}: the form starts under the bar")
    # The last card is white, and the background follows it. The column in the middle has no text.
    middle = CAPTURE_W // 2 * 3
    last = next(y for y in range(SHEET_LIMIT, SHEET_SEAM - shift, -1)
                if row(end, y)[middle:middle + 3] == b"\xff\xff\xff" and row(end, y + 1)[middle:middle + 3] == APP_BG)
    full = blank * (SHEET_EDGE[0] - SHEET_TOP) + top[SHEET_EDGE[0] * line:SHEET_SEAM * line] \
        + end[(SHEET_SEAM - shift) * line:(last + 2) * line] + blank * SHEET_END_SPACE
    write_webp(full, "rgb24", len(full) // line, f"{name}-{code}.webp")

    # The bar. The page rounds the top corners of the sheet, so the dark corners of the capture become background.
    bar = bytearray()
    for y in range(SHEET_TOP, SHEET_EDGE[1]):
        if y >= SHEET_EDGE[0]:
            t = (SHEET_EDGE[1] - y) / (SHEET_EDGE[1] - SHEET_EDGE[0])
            bar += (APP_BG + bytes([round(255 * t * t * (3 - 2 * t))])) * CAPTURE_W
            continue
        cells = [row(top, y)[x * 3:x * 3 + 3] for x in range(CAPTURE_W)]
        for side in (range(CAPTURE_W // 2), range(CAPTURE_W - 1, CAPTURE_W // 2, -1)):
            for x in side:
                if cells[x] == APP_BG:
                    break
                cells[x] = APP_BG
        bar += b"".join(cell + b"\xff" for cell in cells)
    write_webp(bar, "rgba", SHEET_EDGE[1] - SHEET_TOP, f"{name}-bar-{code}.webp")


def import_shots(source):
    """Convert the captures to WebP. Needs sips (macOS), cwebp, and ffmpeg."""
    (SITE / "shots").mkdir(exist_ok=True)
    for code, _ in LANGS:
        if (Path(source) / f"today-end-{code}.png").exists():
            import_today(source, code)
            print(f"shot today-{code}")
        for name in SHEETS:
            if (Path(source) / f"{name}-end-{code}.png").exists():
                import_sheet(source, name, code)
                print(f"shot {name}-{code}")
    for shot in SHOTS[1:]:
        for code, _ in LANGS:
            png = Path(source) / f"{shot}-{code}.png"
            if not png.exists():
                continue
            with tempfile.TemporaryDirectory() as tmp:
                small = Path(tmp) / "small.png"
                subprocess.run(["sips", "--resampleWidth", str(SHOT_WIDTH), str(png), "--out", str(small)],
                               check=True, capture_output=True)
                subprocess.run(["cwebp", "-quiet", "-q", "90", "-sharp_yuv", str(small), "-o",
                                str(SITE / "shots" / f"{shot}-{code}.webp")], check=True)
            print(f"shot {shot}-{code}")


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
    """The hero phone. The full Today list scrolls inside the screen, under the bars, as in the app.
    With no script it is this one picture."""
    imgs = ""
    for name in ("today", "today-bars"):
        file = SITE / "shots" / f"{name}-{code}.webp"
        width, height = webp_size(file)
        imgs += (f'<img src="/shots/{file.name}" width="{width}" height="{height}" fetchpriority="high" '
                 f'draggable="false" alt="">')
        if name == "today":
            imgs = (f'<div class="device-scroll" tabindex="0" role="img" '
                    f'aria-label="{e(STRINGS[code]["shots"]["today"]["alt"])}">{imgs}</div>')
    # site.js adds the other screens and the buttons over the controls of the captures. It loads their pictures late.
    words = STRINGS[code]["phone"]
    labels = {name: words["show"].format(words[name]) for name in ("today", "items", "history", "settings", "add")}
    labels |= {"back": words["back"], "close": words["close"], "settingsName": words["settings"], "addName": words["add"]}
    return (f'<div class="device" role="group" aria-label="{e(words["label"])}" data-shots="{code}" '
            f'data-labels="{e(json.dumps(labels, ensure_ascii=False))}"><div class="device-screen">{imgs}</div>'
            f'<span class="island" aria-hidden="true"></span></div>')


def jars(code):
    """Three supplement jars with made-up brand labels, cut out as the app cuts out a photo of an item."""
    imgs = "".join(
        f'<img src="/shots/jar-{name}.webp" width="{w}" height="{h}" loading="lazy" decoding="async" alt="">'
        for name, w, h in [(n, *webp_size(SITE / "shots" / f"jar-{n}.webp")) for n in JARS])
    return f'<div class="jars" role="img" aria-label="{e(STRINGS[code]["shots"]["photos"]["alt"])}">{imgs}</div>'


def stage(code, shot):
    """The picture of a block. The reminder block shows the widget and the reminder on a wallpaper."""
    if shot == "duo":
        t = mock.load(code)
        return (f'<div class="wallpaper">{picture(code, "widget", mock.widget(t), " enter d2")}'
                f'{picture(code, "notification", mock.reminder(t), " enter d3")}</div>')
    if shot == "photos":
        return jars(code)
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


def layout(code, page, title, desc, main, head=""):
    s = STRINGS[code]
    f = s["footer"]
    here = ORIGIN + url(code, page)
    alternates = "".join(f'<link rel="alternate" hreflang="{c}" href="{ORIGIN}{url(c, page)}">\n' for c, _ in LANGS)
    banner = (f'<meta name="apple-itunes-app" content="app-id={re.search(r"id(\d+)", STORE_URL).group(1)}">\n'
              if RELEASED else "")
    # Google Search Console reads this tag on the home page to confirm the owner of the site. Keep it.
    if page == "index.html" and code == LANGS[0][0]:
        banner += '<meta name="google-site-verification" content="RS5MimbYtPjYD6RQrpYsM9gtvHPVW_mOC43pGs5eqRc">\n'
    cta = f'<a class="bar-cta" href="{e(STORE_URL)}">{e(s["store"]["download"])}</a>\n' if RELEASED else ""
    locales = "".join(f'<meta property="og:locale:alternate" content="{OG_LOCALE[c]}">\n' for c, _ in LANGS if c != code)
    # The social preview card of the language (social.py), and its words for a screen reader.
    card = f'{ORIGIN}/og{"-" + FOLDER[code] if FOLDER[code] else ""}.png'
    card_alt = e(f'Maru. {" ".join(part.strip() for part in s["home"]["h1"].split("|"))} {s["shots"]["today"]["alt"]}')
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
<a class="icon-btn" href="{GITHUB}" aria-label="{e(s["github"])}" data-tip="GitHub">{icon("github")}</a>
{cta}</nav>
</div></header>
{main}
<footer class="site-footer">
<div class="footer-inner">
<ul class="footer-links"><li><a href="{url(code, "faq/index.html")}">{e(f["faq"])}</a></li><li><a href="{url(code, "support/index.html")}">{e(f["support"])}</a></li><li><a href="{url(code, "privacy/index.html")}">{e(f["privacy"])}</a></li><li><a href="{GITHUB}">{e(f["source"])}</a></li></ul>
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
        f'<h2 class="enter">{phrases(b["title"], load=False)}</h2><p class="lede enter d1">{e(b["text"])}</p></div>'
        f'<div class="feature-stage{"" if b["shot"] == "duo" else " enter d2"}">{stage(code, b["shot"])}</div></article>\n'
        for i, b in enumerate(s["blocks"]))
    store_link = f'<a href="{e(STORE_URL)}">{e(s["store"]["badge_alt"])}</a>' if RELEASED else ""
    first, *rest = s["trust"]
    trust = f'<li><a href="{GITHUB}">{icon("github")}{e(first)}</a></li>' + "".join(f"<li>{e(t)}</li>" for t in rest)
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
    return {"privacy": url(code, "privacy/index.html"), "faq": url(code, "faq/index.html"), "github": GITHUB}


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


def sitemap():
    rows = []
    for page in PAGES:
        alternates = "".join(
            f'<xhtml:link rel="alternate" hreflang="{c}" href="{ORIGIN}{url(c, page)}"/>' for c, _ in LANGS)
        alternates += f'<xhtml:link rel="alternate" hreflang="x-default" href="{ORIGIN}{url("en", page)}"/>'
        rows += [f"  <url><loc>{ORIGIN}{url(code, page)}</loc>{alternates}</url>" for code, _ in LANGS]
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
    rows = ["/compare.html /faq/ 301", "/us / 301", "/us/* /:splat 301"]
    for code, folder in LANGS:
        prefix = f"/{folder}" if folder else ""
        rows += [f"{prefix}/{old} {url(code, new)} 301" for old, new in OLD_PAGES.items()]
    for old, new in [("zh-hans", "cn"), ("ja", "jp"), ("ko", "kr")]:
        rows += [f"/{old} /{new}/ 301", f"/{old}/* /{new}/:splat 301"]
    return "\n".join(rows) + "\n"


def llms():
    state = "It is in the App Store." if RELEASED else "It is not in the App Store yet."
    devices = ", ".join(DEVICE_NAMES[d][1] for d in DEVICES)
    languages = "\n".join(f"- {name}: {ORIGIN}{url(code, 'index.html')}" for code, name in [
        ("en", "English"), ("zh-Hans", "Simplified Chinese"), ("ja", "Japanese"), ("es", "Spanish"), ("de", "German"), ("ko", "Korean")])
    return f"""# Maru

> Maru is a small app for daily vitamins, supplements, and simple medication schedules. It reminds you at the times you choose, shows what to take now, and keeps a record. {state}

Facts:
- Runs on: {devices}.
- Free, with no subscription, no ads, no account, and no limit on items. Optional tips unlock nothing.
- Items and records stay on the device. Optional usage statistics never include names, doses, or times.
- Today screen: record a dose with one tap.
- Local reminders at the times you choose, with an optional "Remind Again" of up to 12 more reminders for a dose.
- Schedules: every day, every other day, every few days (every 3 to 30 days), or days on and days off (for example 21 on and 7 off). As-needed items have no reminders.
- History with undo and correction. Record export, backup, and restore.
- Home Screen widgets.
- Item photos: take or choose a photo of a bottle as the item icon. Maru can remove the background on the device, and it never sends the photo.
- Languages: English, Simplified Chinese, Japanese, Spanish, German, and Korean.
- Maru does not track stock, give medical advice, or pick a dose or a time for you.
- Each iPhone or iPad keeps its own data. Maru has no sync between devices.
- Version 1.0 is for iPhone and iPad. It has no Apple Watch app yet.

Pages:
- [FAQ]({ORIGIN}/faq/): short answers.
- [Privacy]({ORIGIN}/privacy/): what the app stores and what it does not do.
- [Support]({ORIGIN}/support/): hello@maru.day and the feedback form.
- [Source]({GITHUB}): MIT license.

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
    (SITE / "404.html").write_text(not_found(), "utf-8")
    (SITE / "sitemap.xml").write_text(sitemap(), "utf-8")
    (SITE / "_redirects").write_text(redirects(), "utf-8")
    (SITE / "_headers").write_text(HEADERS, "utf-8")
    (SITE / "llms.txt").write_text(llms(), "utf-8")
    print(f"built {len(LANGS) * len(PAGES)} pages")


if __name__ == "__main__":
    main()
