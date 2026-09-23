"""Builds a scene's cover from the scene itself.

    python3 tool/scene_cover.py ~/Desktop/rainy_room

Writes cover.png into the folder. The upload tool picks it up from there and
puts it on the track's lock-screen card, which is otherwise a black
rectangle.

The cover is the first frame of every layer, composited in draw order — the
lit room, the way it looks while something is playing. Square, because that
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
        offset_x, offset_y = layers.get(key, {}).get('offset', [0, 0])
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


if __name__ == '__main__':
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    build(os.path.expanduser(sys.argv[1]))
