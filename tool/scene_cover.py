"""Builds a scene's cover from the scene itself.

    python3 tool/scene_cover.py ~/Desktop/rainy_room

Writes cover.png into the folder. The upload tool picks it up from there and
puts it on the track's lock-screen card, which is otherwise a black
rectangle.

The cover is the first frame of every layer, composited in draw order — the
lit room, the way it looks while something is playing. Tiling layers repeat
across the canvas as they do in the app. Square, because that
is the shape every lock screen and notification wants, and scaled by a whole
number so the pixels stay pixels.

Which square is a judgement call, so scene.json makes it:

    "cover": [x, y, size]

Left out, it takes a centred square. Needs Pillow: pip3 install pillow
"""
import json
import os
import sys

from PIL import Image

SCALE = 3


def build(folder):
    scene = json.load(open(os.path.join(folder, 'scene.json')))
    layers = scene['layers']
    width = scene['canvas']['width']
    height = scene['canvas']['height']

    canvas = Image.new('RGBA', (width, height), (0, 0, 0, 255))
    for name in sorted(os.listdir(folder)):
        if not name.endswith('.png') or name == 'cover.png':
            continue
        key, frames = name[:-4].rsplit('_', 1)
        strip = Image.open(os.path.join(folder, name)).convert('RGBA')
        frame_width = strip.width // int(frames[:-1])
        first = strip.crop((0, 0, frame_width, strip.height))
        layer = layers.get(key, {})
        offset_x, offset_y = layer.get('offset', [0, 0])
        if layer.get('tiles'):
            _tile(canvas, first, offset_x, offset_y)
        else:
            canvas.alpha_composite(first, (offset_x, offset_y))

    size = min(width, height)
    default = [(width - size) // 2, (height - size) // 2, size]
    x, y, size = scene.get('cover', default)

    cover = canvas.crop((x, y, x + size, y + size))
    cover = cover.resize((size * SCALE, size * SCALE), Image.NEAREST)
    out = os.path.join(folder, 'cover.png')
    cover.convert('RGB').save(out)

    print('cover.png  %dx%d from (%d,%d) %dx%d'
          % (size * SCALE, size * SCALE, x, y, size, size))


def _tile(canvas, tile, offset_x, offset_y):
    """Repeats [tile] over the canvas the way the renderer does: from one
    tile before the offset onwards. Drawn once at its offset instead, a
    landscape strip covers a single tile's width and the rest of the window
    is empty — which is what Night Train's first cover looked like."""
    w, h = tile.size
    for y in range(offset_y - h, canvas.height, h):
        for x in range(offset_x - w, canvas.width, w):
            # alpha_composite takes no negative destination; clip instead.
            left, top = max(0, -x), max(0, -y)
            if left >= w or top >= h:
                continue
            canvas.alpha_composite(tile.crop((left, top, w, h)),
                                   (x + left, y + top))


if __name__ == '__main__':
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    build(os.path.expanduser(sys.argv[1]))
