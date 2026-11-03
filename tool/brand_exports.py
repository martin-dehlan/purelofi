"""Writes every logo file the stores and consoles ask for (#93).

    python3 tool/brand_exports.py ~/Desktop/rainy_room

The argument is a scene folder (as for scene_cover.py); the Play feature
graphic shows that room. Everything lands in store/brand/, ready to upload by
hand: App Store Connect, Play Console, RevenueCat and Google Cloud have no
API worth scripting for a handful of images.

Two sources, both in assets/branding/:
- app_icon.png, the 1024 px icon, for anything that wants the icon itself;
- notification_icon.png, whose 24 px heart with the note cut out is the
  mark on its own. It is drawn here in Lamp on Deep, the colours the app
  opens with.

Pixel art only scales by whole numbers with nearest-neighbour, so every size
below is a whole multiple of what it is made from. Needs Pillow.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(__file__))
from scene_cover import composite  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), '..')
BRANDING = os.path.join(ROOT, 'assets', 'branding')
FONTS = os.path.join(ROOT, 'assets', 'fonts')
OUT = os.path.join(ROOT, 'store', 'brand')

# assets/palette/purelofi.gpl
DEEP = (13, 26, 46)
LAMP = (240, 160, 93)
WHITE = (255, 242, 232)
TEAL = (146, 181, 187)

MARK_SIZE = 24


def mark(scale, colour=LAMP):
    """The heart and note, [scale] pixels per pixel, on transparency."""
    source = Image.open(os.path.join(BRANDING, 'notification_icon.png'))
    alpha = source.convert('RGBA').getchannel('A')
    alpha = alpha.resize((MARK_SIZE, MARK_SIZE), Image.NEAREST)
    alpha = alpha.resize((MARK_SIZE * scale, MARK_SIZE * scale), Image.NEAREST)
    out = Image.new('RGBA', alpha.size, colour + (255,))
    out.putalpha(alpha)
    return out


def on_square(size, scale):
    """The mark centred on a Deep square: avatars and consent screens."""
    square = Image.new('RGBA', (size, size), DEEP + (255,))
    m = mark(scale)
    square.alpha_composite(m, ((size - m.width) // 2, (size - m.height) // 2))
    return square.convert('RGB')


def feature_graphic(scene_folder):
    """Play's 1024 x 500 banner: the mark, the name, and a room at 2x."""
    banner = Image.new('RGBA', (1024, 500), DEEP + (255,))
    _, room = composite(scene_folder)
    # 320 x 250 of the room at 2x is exactly the banner's height.
    top = max(0, min(room.height - 250, 150))
    window = room.crop((0, top, 320, top + 250)).resize((640, 500), Image.NEAREST)
    banner.alpha_composite(window, (1024 - 640, 0))

    draw = ImageDraw.Draw(banner)
    banner.alpha_composite(mark(4), (56, 120))
    name = ImageFont.truetype(os.path.join(FONTS, 'PixelifySans.ttf'), 72)
    line = ImageFont.truetype(os.path.join(FONTS, 'Karla.ttf'), 24)
    draw.text((56, 230), 'PureLofi', font=name, fill=WHITE)
    draw.text((58, 326), 'Lo-fi from real musicians', font=line, fill=TEAL)
    return banner.convert('RGB')


def main(scene_folder):
    os.makedirs(OUT, exist_ok=True)
    icon = Image.open(os.path.join(BRANDING, 'app_icon.png')).convert('RGB')

    files = {
        # App Store Connect: 1024, no alpha, no rounded corners.
        'app-store-icon-1024.png': icon,
        # Play Console: 512, drawn at 8x so half is still whole pixels.
        'play-icon-512.png': icon.resize((512, 512), Image.NEAREST),
        'play-feature-graphic-1024x500.png': feature_graphic(scene_folder),
        # Google's OAuth consent screen wants 120 x 120.
        'oauth-logo-120.png': on_square(120, 4),
        # RevenueCat and anything else that wants a square avatar.
        'avatar-512.png': on_square(512, 16),
        'mark-96.png': mark(4),
        'mark-192.png': mark(8),
    }
    for name, image in files.items():
        image.save(os.path.join(OUT, name))
        print('%-36s %dx%d' % (name, image.width, image.height))


if __name__ == '__main__':
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    main(os.path.expanduser(sys.argv[1]))
