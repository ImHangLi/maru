#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = ["numpy>=2", "pillow>=11"]
# ///
"""Draw the alternate app icons of Maru Pro (D112): uv run docs/brand/make_icons.py

The icon is one capsule on a plain background (docs/brand/icon-notes.md). This script is the source of the alternate
icons. It draws each one from vector geometry with an exact anti-aliased edge, so a second run gives the same files.

It writes App/AppIcons.xcassets:
- AppIcon-<Name>.appiconset: one alternate icon, 1024 x 1024 with no alpha channel, with a dark and a tinted look.
- IconPreview-<Name>.imageset: the picture of each choice in Settings, in the light and the dark look.

The primary icon in App/Assets.xcassets stays as it is. The geometry and the pink gradient below are fitted to its
AppIcon.png (mean error under 0.1 of 255 for each channel), so the "Default" preview matches it.
"""

import json
import shutil
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / "App/AppIcons.xcassets"
PRIMARY = ROOT / "App/Assets.xcassets/AppIcon.appiconset"

SIZE = 1024
PREVIEW = 192  # 64 points at 3x.
# The capsule: a segment at 45 degrees through the center, with round ends. Fitted to the shipped AppIcon.png.
CENTER = 512.0
HALF = 130.0  # The x and y offset of each end of the segment from the center.
RADIUS = 136.25
# The gradient runs from the top of the capsule to its bottom.
TOP, BOTTOM = 245.0, 779.0

WHITE = "#FFFFFF"
DARK = "#121212"  # The background of the dark look of the primary icon.


def rgb(value):
    value = value.lstrip("#")
    return np.array([int(value[i:i + 2], 16) for i in (0, 2, 4)], dtype=float)


def hexcolor(color):
    return "#" + "".join(f"{round(c):02X}" for c in np.clip(color, 0, 255))


def gradient(base):
    """The two ends of the gradient for a system color, by the rule of the pink icon.

    The shipped pink runs from #FF5072 to #F71346 around the system pink #FF2D55. The top is the base mixed with
    17 percent white. The bottom is the base with 12 percent more saturation and 3 percent less value.
    """
    color = rgb(base)
    top = color + 0.168 * (255 - color)
    high, low = color.max(), color.min()
    value = high * 0.97
    saturation = min(1.0, (high - low) / high * 1.12) if high else 0.0
    # Keep the hue: scale the distance of each channel from the maximum.
    spread = (high - color) / (high - low) if high > low else np.zeros(3)
    bottom = value - spread * saturation * value
    return hexcolor(top), hexcolor(bottom)


# Each choice: the name in the catalog, the background, the two ends of the capsule gradient, and the dark look.
# The pink is the primary icon, so it gets only a preview. The four colors are the app colors of D025: the system
# colors, and the darker light-mode green of the tint, so the capsule keeps its contrast on white.
PINK = ("#FF5072", "#F71346")
VARIANTS = {
    "Default": {"background": WHITE, "capsule": PINK, "dark": (DARK, PINK)},
    "Blue": {"background": WHITE, "capsule": gradient("#007AFF"), "dark": (DARK, gradient("#0A84FF"))},
    "Purple": {"background": WHITE, "capsule": gradient("#AF52DE"), "dark": (DARK, gradient("#BF5AF2"))},
    "Green": {"background": WHITE, "capsule": gradient("#2CAA4C"), "dark": (DARK, gradient("#30D158"))},
    # The dark look of the primary icon, in every mode.
    "Night": {"background": DARK, "capsule": PINK, "dark": None},
    # One quiet gray capsule: graphite on white, and light gray on the dark background.
    "Mono": {"background": WHITE, "capsule": ("#48484A", "#1C1C1E"), "dark": (DARK, ("#F2F2F7", "#AEAEB2"))},
}


def coverage(size):
    """The share of each pixel inside the capsule, from the exact distance to the segment."""
    scale = size / SIZE
    yy, xx = (np.mgrid[0:size, 0:size] + 0.5) / scale
    ax, ay = CENTER - HALF, CENTER + HALF
    dx, dy = 2 * HALF, -2 * HALF
    px, py = xx - ax, yy - ay
    t = np.clip((px * dx + py * dy) / (dx * dx + dy * dy), 0, 1)
    distance = np.hypot(px - t * dx, py - t * dy)
    # One pixel of anti-aliasing at the output size.
    return np.clip((RADIUS - distance) * scale + 0.5, 0, 1)[..., None], yy


def draw(background, capsule, size=SIZE):
    alpha, yy = coverage(size)
    t = np.clip((yy - TOP) / (BOTTOM - TOP), 0, 1)[..., None]
    top, bottom = rgb(capsule[0]), rgb(capsule[1])
    fill = top * (1 - t) + bottom * t
    image = fill * alpha + rgb(background) * (1 - alpha)
    return Image.fromarray(np.round(image).astype(np.uint8), "RGB")


def write_json(path, images):
    path.write_text(json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")


DARK_LOOK = [{"appearance": "luminosity", "value": "dark"}]
TINTED_LOOK = [{"appearance": "luminosity", "value": "tinted"}]


def write_icon(name, spec):
    folder = CATALOG / f"AppIcon-{name}.appiconset"
    folder.mkdir(parents=True)
    base = f"AppIcon-{name}"
    draw(spec["background"], spec["capsule"]).save(folder / f"{base}.png", optimize=True)
    images = [{"filename": f"{base}.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}]
    if spec["dark"]:
        draw(*spec["dark"]).save(folder / f"{base}-Dark.png", optimize=True)
        images.append({"appearances": DARK_LOOK, "filename": f"{base}-Dark.png", "idiom": "universal",
                       "platform": "ios", "size": "1024x1024"})
    # The system tints a gray picture with the color of the user. Every icon shares the tinted look of the primary icon.
    shutil.copyfile(PRIMARY / "AppIcon-Tinted.png", folder / f"{base}-Tinted.png")
    images.append({"appearances": TINTED_LOOK, "filename": f"{base}-Tinted.png", "idiom": "universal",
                   "platform": "ios", "size": "1024x1024"})
    write_json(folder / "Contents.json", images)


def write_preview(name, spec):
    folder = CATALOG / f"IconPreview-{name}.imageset"
    folder.mkdir(parents=True)
    base = f"IconPreview-{name}"
    draw(spec["background"], spec["capsule"], PREVIEW).save(folder / f"{base}.png", optimize=True)
    images = [{"filename": f"{base}.png", "idiom": "universal"}]
    if spec["dark"]:
        draw(*spec["dark"], PREVIEW).save(folder / f"{base}-Dark.png", optimize=True)
        images.append({"appearances": DARK_LOOK, "filename": f"{base}-Dark.png", "idiom": "universal"})
    write_json(folder / "Contents.json", images)


def main():
    if CATALOG.exists():
        shutil.rmtree(CATALOG)
    CATALOG.mkdir(parents=True)
    # The catalog itself has only "info".
    (CATALOG / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
    for name, spec in VARIANTS.items():
        if name != "Default":
            write_icon(name, spec)
        write_preview(name, spec)
    for name, spec in VARIANTS.items():
        print(name, spec["capsule"], spec["dark"][1] if spec["dark"] else "")


if __name__ == "__main__":
    main()
