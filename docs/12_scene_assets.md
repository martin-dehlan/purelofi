# Scene Assets

**TL;DR:** A scene is a stack of pixel-art sprite layers on a 320×696 canvas,
not a video. Export one folder per scene, named by convention, and upload it
with one command. Video still works as a per-scene fallback.

---

## Why layers and not a video

Four things happen to pixel art inside an MP4, and they add up:

1. **Chroma subsampling (4:2:0).** Colour is stored at half resolution. A 1px
   highlight on a neon sign smears.
2. **DCT ringing.** Hard 1px edges are the worst case for the codec.
3. **Rain is a bitrate sink.** High-frequency noise across the whole frame:
   either the file is huge or the codec smooths it away.
4. **Non-integer scaling on device.** A 1080×1920 video on an iPhone 17
   (1206×2622 physical) is scaled by 1.116. No `FilterQuality` can undo that,
   because `video_player` does the scaling itself.

The fourth is the one that matters most, and it is why video always looks
slightly soft. With sprites the client picks the scale factor itself, always
a whole number, and draws with no filtering at all.

Layers are also cheaper: a full scene is 3–5 MB of PNG against 20–40 MB for a
good one-minute loop, and sprite blits cost less battery than a video decoder.

---

## Canvas and palette

- **Author at 320 × 696.** That is the scene. Not larger — pixel art does not
  get better with more pixels.

  The height is not arbitrary: it matches the ~19.5:9 shape of current
  phones. A 16:9 canvas such as 320×568 forces the renderer to overshoot to
  cover the height, and a third of the width falls off the sides.
- **Safe zone 240 × 560, centred.** Everything that matters goes inside it;
  the edges are cropped on screens of a different shape.
- **One palette of 35 colours for every layer in a scene.** This is the
  single biggest lever for "looks like one piece of work". Lock it in
  Aseprite (`Sprite → Color Mode → Indexed`) before anything else.

  The palette lives at **`assets/palette/purelofi.gpl`** — load it in Aseprite
  via `Palette → Load Palette`. The cool ramps come from the reference art;
  the warm and green ones were measured from the first real scene, because a
  palette that cannot draw warm wood or a plant is a palette the art will
  fight:

  | Ramp | Steps | For |
  |---|---|---|
  | Night | 5 | indigo violet, the base mood |
  | Deep | 5 | night blue into teal, depth |
  | Teal | 4 | teal into ice, highlights on cold things |
  | Coral | 5 | wine into coral, the warm accents |
  | Rose | 3 | dusty transitions, curtains, fabric |
  | Lamp | 5 | the one warm light source |
  | Wood | 4 | desks, shelves, floors |
  | Green | 2 | plants, deliberately saturated so they attract leaves rather than grey-blue |
  | Ink / White | 1 + 1 | near-black, one warm white |

  Lamp is the only light source in a scene, so every shadow has one direction
  to agree with. If a colour is not in the palette, the answer is a different
  colour, not a new one.
- **Gradients belong in the art, dithered** — never as a Flutter widget
  (`docs/09`).

The renderer scales by the smallest whole number of **device** pixels that
covers the viewport, centres the canvas and crops the overflow. Device pixels
rather than logical points is what makes the steps fine enough to land near
the viewport: on a 3x screen the choice is 4x, 5x, 6x, not 1x or 2x.

---

## Generate each scene twice

**Generate the scene once with the lamp lit and once with it dark.** Both are
real art; neither is derived from the other.

This is the lesson that cost the most. The first Rainy Room was generated
lit, and the unlit state was then produced from it — first by darkening, then
by warmth, then by flattening tones, then by a high-pass filter. Every one of
them failed the same way: **darkening preserves brightness relationships.**
The painted light pool was brighter than the desk around it, so it stayed
brighter and kept its shape, however far the numbers were pushed.

What worked was asking PixelLab to redraw it (`edit_image`), and even then it
took two passes: "no warm light" made the model *desaturate* the pool rather
than remove it, leaving a grey cone in exactly the same shape. The second
pass had to say that the desk is **one uniform surface**.

So: ask for both states up front.

```
1. "…desk lamp casting warm amber light…"          → the lit scene
2. "…the desk lamp is switched off, the room is    → the unlit scene
    lit only by cool blue light from the window,
    the desk top is one uniform dark tone…"
```

The unlit version becomes `L08_room`; the lit one becomes `L11_lamp` with
`hide_when_paused`, and the renderer fades between them.

### The two states must line up

Whatever produces the second state, it has to be pixel-aligned with the
first, or the furniture drifts during the fade. Two numbers say whether it is:

| Check | How | Good |
|---|---|---|
| Alignment | difference of the two edge images | under ~3 |
| Light removed | count of pixels where R − B > 25 | near zero |

`edit_image` scored 2.3 on alignment; `create_image_pixflux` with a strong
init image scored 10.1 and kept the lamp on anyway.

## A light that never fully goes out

Removing a light entirely is harder than it looks, and a room lit only by a
window can read as flat. The Rainy Room solves it as a **night light**: the
lamp keeps a small warm glow at all times and comes up to full when the music
plays.

Three layers do it:

| Layer | Behaviour |
|---|---|
| `L08_room` | the unlit room, always drawn |
| `L09_nightlight` | the lampshade plus a small halo, always drawn, ~35% opacity |
| `L11_lamp` | the fully lit room, `hide_when_paused`, fades in over 2.2s |

The night light is baked at low opacity rather than given a new flag, and the
lit layer is opaque, so at full fade it covers the night light exactly.

It is also the honest fix when a scene refuses to give up its light pool: a
faint pool under a night light is expected, so it stops reading as a mistake.

## Leave the effects out of the art

Anything that should move must **not** be painted into the scene:

- **No rain on the glass.** Painted streaks are static, and they dominate
  whatever animated rain is layered behind them. Removing them afterwards
  cost 4499 pixels of repair on the first scene.
- **No steam over a mug.** Same reason; it ends up doubled.
- **No reflections of the lamp** in the window if the lamp can be switched
  off, or the reflection stays lit while the lamp is dark.

Add `no rain on the glass, no steam, no reflections` to the prompt.

## The folder contract

One folder per scene: sprite strips plus a `scene.json`.

```
rainy_room/
  scene.json
  L00_room_1f.png
  L03_rain_6f.png
  L09_reels_8f.png
```

### File names

```
L<zz>_<name>_<frames>f.png
```

| Part | Meaning |
|---|---|
| `L03` | draw order, 0 = furthest back, unique within a scene |
| `rain` | the layer's name, used as the key in `scene.json` |
| `6f` | frame count |

An animation is a **horizontal strip**: 6 frames of a 64×64 sprite is one
384×64 PNG. The image width must divide evenly by the frame count.

### scene.json

```json
{
  "title": "Rainy Room",
  "canvas": { "width": 320, "height": 696 },
  "layers": {
    "L00_room":  { "parallax": 1.0 },
    "L03_rain":  { "fps": 12, "tiles": true, "parallax": 1.0 },
    "L09_reels": { "fps": 10, "offset": [144, 470], "only_while_playing": true },
    "L12_car":   { "fps": 12, "event_interval": [40, 90] }
  }
}
```

| Key | Default | Meaning |
|---|---|---|
| `fps` | `0` | Frames per second. Required when frames > 1, forbidden when frames = 1. |
| `offset` | `[0, 0]` | Position on the canvas, in canvas pixels. |
| `parallax` | `1.0` | How far the layer moves with the camera. 0.5 moves half as far. |
| `tiles` | `false` | Repeat across the canvas instead of placing once. |
| `only_while_playing` | `false` | Advances only while audio plays. |
| `event_interval` | — | `[min, max]` seconds: fires once at random in that range instead of looping. |

Every sprite needs an entry and every entry a sprite. The parser refuses
anything else, because a silently missing layer is the kind of mistake nobody
notices for a week.

---

## Uploading

```bash
dart run tool/upload_scene.dart --scene rainy_room --dir ~/Desktop/rainy_room --dry-run
dart run tool/upload_scene.dart --scene rainy_room --dir ~/Desktop/rainy_room
```

`--dry-run` validates and prints the layer table without touching anything.
The real run uploads the sprites to `storage/scenes/<slug>/`, upserts the
scene and **replaces** its layers, so a layer deleted from the folder
disappears from the scene too.

`assets/dev/scenes/test_room/` is a working example, generated by
`tool/generate_test_scene.py`.

---

## Making a scene feel alive

### Coprime loop lengths

If everything loops at four seconds, the eye catches the pattern in twenty.
Give each layer a frame count that shares no factors with the others — 5, 7,
9, 11, 13, 17, 23 — and the combination does not repeat exactly for hours.

| Layer | Frames | fps | Loop |
|---|---|---|---|
| Rain, near | 6 | 12 | 0.5 s |
| Steam | 7 | 6 | 1.17 s |
| Cat breathing | 13 | 4 | 3.25 s |
| Curtain | 17 | 3 | 5.67 s |
| Dust | 23 | 2 | 11.5 s |

### Rare events

Not everything should loop. An event layer fires once at a random point in
its interval, then rests on its first frame:

| Event | Interval |
|---|---|
| Car headlights sweep the wall | 40–90 s |
| Cat stretches and turns over | 3–6 min |
| Distant lightning | 2–5 min |
| Someone passes the window | 90–200 s |

Only one event runs at a time. Two at once reads as chaos, not life.

### Reacting to the music

Layers marked `only_while_playing` stop when the audio does. The tape reels
standing still while the rain keeps falling is the detail people notice
without being able to say why.

### Camera drift

The renderer moves the whole scene one canvas pixel out and back over 23
seconds, with each layer shifted by its `parallax`. Nothing to author — but
worth knowing, because it is why a scene of still layers still feels alive.

---

## The checklist

In rough order of how much each one buys you:

- [ ] One palette across every layer
- [ ] Coprime loop lengths
- [ ] Tape reels stop when the music pauses
- [ ] At least three rare events
- [ ] One light source; every shadow agrees with it
- [ ] Rain has at least two depths
- [ ] Something moves very slowly (clouds, 1px per 8s)
- [ ] Nothing blinks on a one-second beat — it reads as cheap immediately

---

## If a scene has to be a video

Leave `scene_layers` empty and set `video_url`. The player falls back to
`video_player` with `BoxFit.cover`. Worth doing properly:

```bash
ffmpeg -framerate 12 -i frame_%04d.png \
  -vf "scale=1600:2840:flags=neighbor,fps=24" \
  -c:v libx264 -profile:v high -pix_fmt yuv420p \
  -crf 16 -g 48 -movflags +faststart -an \
  rainy_room.mp4
```

- `flags=neighbor` — scale up by a whole number **before** encoding, so the
  "pixels" become 4×4 blocks the codec can keep.
- 60–120 second loops: the seam is visible, so make it rare.
- Last frame must differ from the first, or the loop point stutters.
- `-an`: the scene is silent, the music comes from the audio player.
