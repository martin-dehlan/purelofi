#!/usr/bin/env python3
"""Generates the development placeholder scene.

Flat shapes, no art — just enough layers to prove the renderer, the parallax
and the drift work before the real PixelLab assets exist. Regenerate with:

    python3 tool/generate_test_scene.py
"""

import math
import struct
import zlib
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "assets/dev/scenes/test_room"

# One palette for every layer — the same rule the real scenes follow.
NIGHT = (18, 20, 34, 255)
NIGHT_SOFT = (26, 30, 48, 255)
HORIZON = (38, 44, 70, 255)
BUILDING = (12, 13, 24, 255)
WINDOW = (240, 196, 112, 255)
STAR = (198, 214, 255, 255)
RAIN = (150, 178, 220, 190)
METAL = (196, 202, 214, 255)
CLEAR = (0, 0, 0, 0)


def write_png(path, rows):
    """rows: list of rows of RGBA tuples."""
    raw = b""
    for row in rows:
        raw += b"\x00" + b"".join(struct.pack("4B", *px) for px in row)

    def chunk(tag, data):
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    width = len(rows[0])
    height = len(rows)
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    path.write_bytes(png)
    print(f"  {path.name}  {width}x{height}")


def blank(w, h, colour=CLEAR):
    return [[colour for _ in range(w)] for _ in range(h)]


def sky(w=320, h=568):
    """A dithered vertical gradient — gradients belong in the art, not in Dart."""
    rows = []
    for y in range(h):
        t = y / (h - 1)
        base = NIGHT if t < 0.55 else NIGHT_SOFT
        row = []
        for x in range(w):
            # Bayer-ish 2x2 dither towards the horizon colour.
            near_horizon = t > 0.45 and ((x + y) % 2 == 0) and t > 0.45 + 0.4 * ((x * 7 + y * 13) % 5) / 10
            row.append(HORIZON if near_horizon else base)
        rows.append(row)
    return rows


def stars(size=64, frames=4):
    """A tiling twinkle. Coprime with everything else at 1.5 fps."""
    strip = blank(size * frames, size)
    points = [(5, 7), (19, 3), (31, 14), (44, 9), (57, 21), (11, 28), (38, 34),
              (24, 45), (50, 52), (8, 58), (60, 41), (29, 61)]
    for f in range(frames):
        for i, (x, y) in enumerate(points):
            # Each star is lit in some frames and dark in others.
            if (i + f) % 3 != 0:
                strip[y][f * size + x] = STAR
    return strip


def skyline(w=320, h=160):
    rows = blank(w, h)
    x = 0
    heights = [70, 110, 48, 132, 86, 60, 120, 40, 96, 150, 66, 104]
    widths = [34, 22, 40, 26, 30, 44, 20, 38, 28, 24, 42, 32]
    for hi, wi in zip(heights, widths):
        for y in range(h - hi, h):
            for xx in range(x, min(x + wi, w)):
                rows[y][xx] = BUILDING
        # A few lit windows, so the silhouette is not a flat block.
        for wy in range(h - hi + 6, h - 4, 9):
            for wx in range(x + 4, min(x + wi - 3, w), 8):
                if (wx * 3 + wy) % 7 < 3:
                    rows[wy][wx] = WINDOW
                    rows[wy][wx + 1] = WINDOW
        x += wi
        if x >= w:
            break
    return rows


def rain(size=64, frames=6):
    """Diagonal streaks that tile seamlessly in both directions."""
    strip = blank(size * frames, size)
    drops = [(3, 0), (17, 11), (29, 5), (41, 20), (55, 2), (9, 33),
             (23, 40), (37, 27), (49, 47), (61, 36), (13, 54), (45, 58)]
    for f in range(frames):
        shift = f * (size // frames)
        for x0, y0 in drops:
            for k in range(5):
                x = (x0 + k) % size
                y = (y0 + shift + k * 2) % size
                strip[y][f * size + x] = RAIN
    return strip


def reels(w=32, h=16, frames=8):
    """Two spinning reels — the layer that stops when the music stops."""
    strip = blank(w * frames, h)
    for f in range(frames):
        angle = (f / frames) * math.pi
        for cx in (8, 23):
            cy = 8
            r = 5
            for t in range(0, 360, 6):
                rad = math.radians(t)
                x = int(round(cx + r * math.cos(rad)))
                y = int(round(cy + r * math.sin(rad)))
                if 0 <= x < w and 0 <= y < h:
                    strip[y][f * w + x] = METAL
            # Two spokes make the rotation readable.
            for spoke in (0, math.pi / 2):
                for d in range(-r + 1, r):
                    x = int(round(cx + d * math.cos(angle + spoke)))
                    y = int(round(cy + d * math.sin(angle + spoke)))
                    if 0 <= x < w and 0 <= y < h:
                        strip[y][f * w + x] = METAL
    return strip


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    print(f"Writing to {OUT}")
    write_png(OUT / "L00_sky_1f.png", sky())
    write_png(OUT / "L01_stars_4f.png", stars())
    write_png(OUT / "L02_skyline_1f.png", skyline())
    write_png(OUT / "L03_rain_6f.png", rain())
    write_png(OUT / "L04_reels_8f.png", reels())


if __name__ == "__main__":
    main()
