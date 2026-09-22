"""Crops every sprite strip in a scene folder to the pixels it actually uses,
and writes the offset that puts each one back where it was.

    python3 tool/trim_scene.py ~/Desktop/rainy_room            # report only
    python3 tool/trim_scene.py ~/Desktop/rainy_room --apply    # rewrite

A full-canvas strip for a 4x4 pixel LED costs 22 MB once decoded; cropped it
costs 32 KB. Flutter's image cache holds 100 MB and drops the biggest entries
past that, so an oversized scene loses its largest layers with no error. See
docs/12. Needs Pillow: pip3 install pillow
"""
import json, os, sys
from PIL import Image

d = sys.argv[1]
apply = '--apply' in sys.argv
sj = json.load(open(os.path.join(d, 'scene.json')))
layers = sj['layers']
W, H = sj['canvas']['width'], sj['canvas']['height']

total_before = total_after = 0
changes = {}

for name in sorted(os.listdir(d)):
    if not name.endswith('.png'):
        continue
    key, frames = name[:-4].rsplit('_', 1)
    n = int(frames[:-1])
    im = Image.open(os.path.join(d, name)).convert('RGBA')
    fw, fh = im.width // n, im.height
    settings = layers.get(key, {})
    ox, oy = settings.get('offset', [0, 0])

    # Union of every frame's used area, in frame coordinates.
    left, top, right, bottom = fw, fh, 0, 0
    for f in range(n):
        bb = im.crop((f * fw, 0, (f + 1) * fw, fh)).getbbox()
        if bb is None:
            continue
        left, top = min(left, bb[0]), min(top, bb[1])
        right, bottom = max(right, bb[2]), max(bottom, bb[3])

    total_before += im.width * im.height * 4 / 1048576
    if right <= left:
        print('%-26s empty' % name)
        continue

    # One pixel of slack, so nothing is clipped by an off-by-one.
    left, top = max(0, left - 1), max(0, top - 1)
    right, bottom = min(fw, right + 1), min(fh, bottom + 1)
    nw, nh = right - left, bottom - top

    after = nw * n * nh * 4 / 1048576
    total_after += after
    if (nw, nh) == (fw, fh):
        print('%-26s %dx%d already tight (%.1f MB)' % (name, fw, fh, after))
        continue

    out = Image.new('RGBA', (nw * n, nh))
    for f in range(n):
        out.paste(im.crop((f * fw + left, top, f * fw + right, bottom)),
                  (f * nw, 0))

    print('%-26s %dx%d -> %dx%d at (%d,%d)  %.1f -> %.2f MB'
          % (name, fw, fh, nw, nh, ox + left, oy + top,
             im.width * im.height * 4 / 1048576, after))
    changes[key] = (ox + left, oy + top)
    if apply:
        out.save(os.path.join(d, name))
        settings['offset'] = [ox + left, oy + top]
        layers[key] = settings

print('\ntotal decoded %.1f -> %.1f MB' % (total_before, total_after))
if apply:
    json.dump(sj, open(os.path.join(d, 'scene.json'), 'w'), indent=2)
    print('scene.json updated')
