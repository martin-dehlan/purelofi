# Responsive UI Rules

**TL;DR:** Zero fixed spacing or font sizes. All sizing is derived from `MediaQuery` height/width at build time. Use the `ResponsiveContext` extension from `lib/common/utils/responsive.dart`.

---

## The Core Rule

**NEVER use fixed pixel values for spacing or font sizes.**

```dart
// WRONG
SizedBox(height: 16)
Text('Rainy Room', style: TextStyle(fontSize: 18))
Padding(padding: EdgeInsets.all(12))

// RIGHT
SizedBox(height: context.spaceM)
Text('Rainy Room', style: TextStyle(fontSize: context.fontM))
Padding(padding: EdgeInsets.all(context.spaceS))
```

---

## Standard Spacing Formulas

All derived from `MediaQuery.of(context).size.height` (h):

| Token | Formula | ~375pt result |
|---|---|---|
| `spaceXs` | `h * 0.005` | ~1.9pt |
| `spaceS` | `h * 0.01` | ~3.7pt |
| `spaceM` | `h * 0.02` | ~7.5pt |
| `spaceL` | `h * 0.03` | ~11.2pt |
| `spaceXl` | `h * 0.04` | ~15pt |
| `spaceXxl` | `h * 0.06` | ~22.5pt |

## Standard Font Size Formulas

Derived from `MediaQuery.of(context).size.width` (w):

| Token | Formula | ~375pt result |
|---|---|---|
| `fontXs` | `w * 0.025` | ~9.4pt |
| `fontS` | `w * 0.032` | ~12pt |
| `fontM` | `w * 0.040` | ~15pt |
| `fontL` | `w * 0.050` | ~18.75pt |
| `fontXl` | `w * 0.065` | ~24.4pt |
| `fontXxl` | `w * 0.080` | ~30pt |

---

## ResponsiveContext Extension

File: `lib/common/utils/responsive.dart`

```dart
import 'package:flutter/material.dart';

extension ResponsiveContext on BuildContext {
  Size get screenSize => MediaQuery.of(this).size;
  double get screenHeight => screenSize.height;
  double get screenWidth => screenSize.width;

  // Spacing (height-based)
  double get spaceXs  => screenHeight * 0.005;
  double get spaceS   => screenHeight * 0.01;
  double get spaceM   => screenHeight * 0.02;
  double get spaceL   => screenHeight * 0.03;
  double get spaceXl  => screenHeight * 0.04;
  double get spaceXxl => screenHeight * 0.06;

  // Font sizes (width-based)
  double get fontXs  => screenWidth * 0.025;
  double get fontS   => screenWidth * 0.032;
  double get fontM   => screenWidth * 0.040;
  double get fontL   => screenWidth * 0.050;
  double get fontXl  => screenWidth * 0.065;
  double get fontXxl => screenWidth * 0.080;

  // Utility
  double get horizontalPadding => screenWidth * 0.05;
  double get cardBorderRadius  => screenWidth * 0.03;
  bool get isSmallScreen => screenHeight < 700;
}
```

---

## Usage Examples

```dart
// Overlay controls
Column(
  children: [
    SizedBox(height: context.spaceM),
    Text(track.title, style: TextStyle(fontSize: context.fontL)),
    SizedBox(height: context.spaceS),
  ],
)

// Padding
Padding(
  padding: EdgeInsets.symmetric(
    horizontal: context.horizontalPadding,
    vertical: context.spaceM,
  ),
  child: PlayerControls(),
)
```

---

## Anti-Patterns

```dart
// NO — const spacing
const SizedBox(height: 16)

// NO — fixed EdgeInsets
EdgeInsets.all(12)

// NO — fixed font size
TextStyle(fontSize: 14)

// YES — responsive
SizedBox(height: context.spaceM)
```

---

## Notes

- The fullscreen scene video is the exception to sizing tokens: it should use
  `BoxFit.cover` inside a `SizedBox.expand` / `Positioned.fill`, not derived
  spacing — it must fill the screen edge to edge.
- `context` must be available — never compute responsive values outside
  `build()`.
- For fixed-aspect assets (pixel icons), prefer `AspectRatio` over hardcoded
  height.
