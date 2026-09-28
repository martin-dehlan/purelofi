# 09 - Design Principles

## TL;DR

```
ANTI-AI-SLOP:
NO: Gradients, glassmorphism, heavy shadows, 3+ card levels, >2 buttons/screen
YES: Theme colors only, clear hierarchy, generous spacing, minimal elevation

MANDATORY:
- Colors: Theme.of(context).colorScheme — minimize manual color assignments
- Spacing: ONLY MediaQuery (NO fixed numbers)
- Widgets: Separate classes (NO _build methods)
- Buttons/controls: keep the player chrome minimal (play/pause + scene + info)
```

> **Pixel-art clarification for PureLofi:** the retro/pixel *vibe* comes from
> the **scenes** alone — the sprite layers of a room (see
> [`docs/12`](12_scene_assets.md)). What keeps them crisp is integer scaling:
> the renderer picks a whole-number scale factor and draws with
> `FilterQuality.none`, so one authored pixel is always an exact block of
> screen pixels.
>
> The chrome does **not** repeat it (#67). Pixel type and pixel icons over a
> pixel room read as a costume, so the text is Karla (numbers in DM Mono) and
> the icons are flat filled shapes drawn by `AppIcon`, coloured from the
> theme. The one pixel element left in the chrome is the PureLofi wordmark in
> Pixelify Sans. Do not fake "pixel art" with gradients, glows, or drop
> shadows in Dart either — put that character in the scene assets.

## Pre-Flight Checklist

- [ ] Colors from `colorScheme` only
- [ ] No gradients/glassmorphism (even to "make it look retro")
- [ ] MediaQuery for all spacing
- [ ] Minimal player chrome — don't crowd the scene
- [ ] Clear hierarchy (now-playing title > controls > info)
- [ ] Separate Widget classes (no `_build*` methods)
- [ ] Icons are `AppIcon` glyphs, coloured from `colorScheme` — no image icons
- [ ] Type from the theme (Karla); `AppFonts.mono` for numbers, `AppFonts.wordmark`
      only for the PureLofi wordmark

---

## ANTI-AI-SLOP RULES (ABSOLUTE)

### FORBIDDEN
```dart
gradient: LinearGradient(...)           // NEVER
BackdropFilter(filter: ImageFilter...)  // NEVER
BorderRadius.circular(30)              // Max: width * 0.03
BoxShadow(blurRadius: 50)             // Max blur: 10
Widget _buildControls() { ... }        // Extract to class
Color(0xFF123456)                      // Use colorScheme
Colors.blue                            // Use colorScheme
```

### REQUIRED
```dart
final cs = Theme.of(context).colorScheme;
color: cs.surface                      // Theme colors
elevation: 0                           // Minimal elevation
SizedBox(height: h * 0.03)            // MediaQuery spacing
class PlayerControls extends StatelessWidget // Separate widgets
AppIcon(AppGlyph.play, size: context.screenWidth * 0.13)
```

---

## Player-specific guidance

- The scene video fills the screen (`BoxFit.cover`). Controls float **over** it
  and **auto-hide after 4s** of inactivity — the scene is the hero, not the UI.
- For legibility of text/icons over a bright video frame, use a subtle solid
  scrim (`cs.scrim.withOpacity(0.3)` or a semi-transparent `cs.surface`), **not**
  a gradient. A flat scrim is allowed; a `LinearGradient` scrim is not.
- Keep interactive controls to the essentials: play/pause, scene switch, info
  (BTS). No settings drawer, no clutter.

## Color System

```dart
final cs = Theme.of(context).colorScheme;

cs.onSurface          // primary text
cs.onSurfaceVariant   // secondary text
cs.surface            // modal / sheet background
cs.primary            // the single accent (e.g. active control)
cs.error              // errors
cs.scrim              // overlay scrim over video
```

Default the app to a **dark** theme — it suits a night-time lo-fi player and
keeps the scene video the brightest thing on screen.

---

## Widget Architecture

```dart
// NEVER
Widget _buildControls() { ... }

// ALWAYS
class PlayerControls extends StatelessWidget { ... }
```

---

## File Size Limits

```
Widget: 300 lines max
Controller: 400 lines max
Service/Repo: 300 lines max
```
