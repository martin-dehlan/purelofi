# Branding artwork

Three files, and each one has a different job. Drop them here and run:

```bash
dart run flutter_launcher_icons
```

That writes every iOS and Android icon size from them. The generated sets are
committed; nothing regenerates on build.

## `app_icon.png` — 1024 × 1024

The icon as it appears on iOS: the full square, artwork edge to edge. iOS
draws the rounded corners itself, so do not round them, and do not add
padding or a transparent border — iOS shows transparency as black. Pixel art
scales cleanly only by whole numbers, so work at 128 × 128 and scale 8×, or
at 256 and scale 4×, with nearest-neighbour.

## `app_icon_foreground.png` — 1024 × 1024

Android's adaptive icon, which is masked into whatever shape the launcher
uses — circle, squircle, teardrop. Transparent background, and the motif
inside the middle **66%** (a 672 px circle); anything outside can be cropped.
The background is the flat colour `#0D1A2E`, set in `pubspec.yaml`.

## `notification_icon.png` — 96 × 96 (optional)

Android draws the media-notification icon as a **silhouette**: every opaque
pixel becomes white, colour is discarded. So it must be one flat shape with
transparency around it — a lamp, a cassette, not the whole scene. Without it
Android silhouettes the launcher icon, which usually turns into a white blob.

## Colours

From `assets/palette/purelofi.gpl`. The launch screen and the adaptive icon
background are Deep `#0D1A2E`, the night the scene opens on.
