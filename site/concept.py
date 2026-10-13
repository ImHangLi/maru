#!/usr/bin/env python3
"""Cut the two product pictures from real simulator captures: python3 site/concept.py DIR

DIR holds widget.png and reminder-expanded.png (1206 x 2622). The script writes shots/widget.webp and
shots/notification.webp with a transparent background, at the same scale.
Every pixel comes from the captures. Nothing is drawn.
It needs sips (macOS) and cwebp, and no Python package.
"""

import struct
import subprocess
import sys
import tempfile
import zlib
from pathlib import Path

SITE = Path(__file__).resolve().parent
# The pictures keep 73% of the capture size. A capture has 3 pixels for each point, so this is enough for a 2x screen.
SCALE = 0.73
WHITE = 250

# Crop boxes in the capture, as (left, top, width, height). Each box holds one element and a margin of wallpaper.
WIDGET_BOX = (60, 250, 1090, 534)
REMINDER_BOX = (28, 1212, 1150, 496)
# The notification card is in the first rows of REMINDER_BOX. Its action is below this line, and is not used.
CARD_ROWS = 268
# The corners of a card are inside a square of this size. Outside the squares, the edges of a card are straight.
CORNER = 130


def read_png(path):
    """Return (width, height, rows) with rows of RGB tuples lists. Reads 8-bit RGB and RGBA files."""
    data = path.read_bytes()
    pos, idat, width, height, channels = 8, b"", 0, 0, 0
    while pos < len(data):
        length, kind = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        if kind == b"IHDR":
            width, height, depth, color = struct.unpack(">IIBB", body[:10])
            assert depth == 8 and color in (2, 6), "an 8-bit RGB or RGBA file is necessary"
            channels = 3 if color == 2 else 4
        elif kind == b"IDAT":
            idat += body
        pos += 12 + length
    raw = zlib.decompress(idat)
    stride = width * channels
    rows, previous = [], bytearray(stride)
    for y in range(height):
        start = y * (stride + 1)
        kind, line = raw[start], bytearray(raw[start + 1:start + 1 + stride])
        for i in range(stride):
            left = line[i - channels] if i >= channels else 0
            up = previous[i]
            corner = previous[i - channels] if i >= channels else 0
            if kind == 1:
                line[i] = (line[i] + left) & 255
            elif kind == 2:
                line[i] = (line[i] + up) & 255
            elif kind == 3:
                line[i] = (line[i] + (left + up) // 2) & 255
            elif kind == 4:
                estimate = left + up - corner
                a, b, c = abs(estimate - left), abs(estimate - up), abs(estimate - corner)
                line[i] = (line[i] + (left if a <= b and a <= c else up if b <= c else corner)) & 255
        rows.append([tuple(line[x * channels:x * channels + 3]) for x in range(width)])
        previous = line
    return width, height, rows


def write_png(path, rows, alpha):
    height, width = len(rows), len(rows[0])
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        for x in range(width):
            raw += bytes(rows[y][x]) + bytes([alpha[y][x]])

    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body))

    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
                     + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b""))


def crop(source, box):
    left, top, width, height = box
    with tempfile.TemporaryDirectory() as tmp:
        part = Path(tmp) / "part.png"
        subprocess.run(["sips", "-c", str(height), str(width), "--cropOffset", str(top), str(left), str(source),
                        "--out", str(part)], check=True, capture_output=True)
        return read_png(part)[2]


def edge_alpha(line):
    """The alpha of one line of pixels across a white card. The first and last white pixels are the edges.
    The pixel outside each edge is a mix of white and wallpaper, so it gets a part alpha. All others outside get 0."""
    low = [min(p) for p in line]
    size = len(low)
    run = 8
    first = next((i for i in range(size - run) if all(v >= WHITE for v in low[i:i + run])), None)
    if first is None:
        return [0] * size
    last = next(i for i in range(size - 1, run, -1) if all(v >= WHITE for v in low[i - run + 1:i + 1]))
    alpha = [255 if first <= i <= last else 0 for i in range(size)]
    for edge, step in ((first, -1), (last, 1)):
        near, far = edge + step, edge + 3 * step
        if 0 <= far < size and low[far] < WHITE:
            alpha[near] = max(0, min(255, round(255 * (low[near] - low[far]) / (255 - low[far]))))
    return alpha


def middle(values):
    return sorted(values)[len(values) // 2]


def cut_card(rows):
    """Cut a white card with rounded corners. The straight edges come from the box of the card.
    In the four corner squares, the alpha follows the real edge of the card in both directions."""
    height, width = len(rows), len(rows[0])
    across = [edge_alpha(row) for row in rows]
    down = [edge_alpha([rows[y][x] for y in range(height)]) for x in range(width)]
    solid_rows = [a for a in across if 255 in a]
    solid_columns = [a for a in down if 255 in a]
    left = middle([a.index(255) for a in solid_rows])
    right = middle([width - 1 - a[::-1].index(255) for a in solid_rows])
    top = middle([a.index(255) for a in solid_columns])
    bottom = middle([height - 1 - a[::-1].index(255) for a in solid_columns])
    alpha = []
    for y in range(height):
        line = []
        for x in range(width):
            inside = left <= x <= right and top <= y <= bottom
            corner = min(x - left, right - x) < CORNER and min(y - top, bottom - y) < CORNER
            line.append(min(across[y][x], down[x][y]) if inside and corner else 255 if inside else 0)
        alpha.append(line)
    # A pixel on the edge is a mix with the wallpaper. Make it white, and let the alpha carry the edge.
    pixels = [[(255, 255, 255) if 0 < alpha[y][x] < 255 else rows[y][x] for x in range(width)] for y in range(height)]
    return pixels, alpha


def clean_bottom(pixels, alpha):
    """The Home Screen shines through the lower edge of the widget as a gray mark in the middle.
    Replace each darker pixel there with the pixel of the same row, one quarter of the card to its left."""
    ys = [y for y, line in enumerate(alpha) if 255 in line]
    xs = [x for x in range(len(alpha[0])) if alpha[ys[len(ys) // 2]][x] == 255]
    top, bottom, left, right = ys[0], ys[-1], xs[0], xs[-1]
    shift = (right - left) // 4
    for y in range(bottom - (bottom - top) // 4, bottom + 1):
        for x in range(left + shift + CORNER, right - CORNER):
            if alpha[y][x] == 255 and min(pixels[y][x]) < min(pixels[y][x - shift]):
                pixels[y][x] = pixels[y][x - shift]
    return pixels, alpha


def save(name, pixels, alpha):
    """Trim the transparent margin, and write the picture at SCALE."""
    ys = [y for y, line in enumerate(alpha) if any(line)]
    xs = [x for x in range(len(alpha[0])) if any(line[x] for line in alpha)]
    pixels = [line[xs[0]:xs[-1] + 1] for line in pixels[ys[0]:ys[-1] + 1]]
    alpha = [line[xs[0]:xs[-1] + 1] for line in alpha[ys[0]:ys[-1] + 1]]
    with tempfile.TemporaryDirectory() as tmp:
        png = Path(tmp) / "cut.png"
        write_png(png, pixels, alpha)
        subprocess.run(["cwebp", "-quiet", "-q", "92", "-alpha_q", "100", "-exact", "-resize",
                        str(round(len(pixels[0]) * SCALE)), "0", str(png), "-o", str(SITE / "shots" / f"{name}.webp")],
                       check=True)
    print(f"picture {name}")


def main():
    source = Path(sys.argv[1])
    save("widget", *clean_bottom(*cut_card(crop(source / "widget.png", WIDGET_BOX))))
    save("notification", *cut_card(crop(source / "reminder-expanded.png", REMINDER_BOX)[:CARD_ROWS]))


if __name__ == "__main__":
    main()
