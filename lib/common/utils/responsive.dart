import 'package:flutter/material.dart';

/// Every spacing and font size in the app is derived from the screen, never
/// hardcoded (see `docs/03`).
extension ResponsiveContext on BuildContext {
  Size get screenSize => MediaQuery.of(this).size;
  double get screenHeight => screenSize.height;
  double get screenWidth => screenSize.width;

  // Spacing (height-based)
  double get spaceXs => screenHeight * 0.005;
  double get spaceS => screenHeight * 0.01;
  double get spaceM => screenHeight * 0.02;
  double get spaceL => screenHeight * 0.03;
  double get spaceXl => screenHeight * 0.04;
  double get spaceXxl => screenHeight * 0.06;

  // Font sizes (width-based), snapped to whole device pixels so the pixel
  // font stays crisp.
  double get fontXs => pixel(screenWidth * 0.025);
  double get fontS => pixel(screenWidth * 0.032);
  double get fontM => pixel(screenWidth * 0.040);
  double get fontL => pixel(screenWidth * 0.050);
  double get fontXl => pixel(screenWidth * 0.065);
  double get fontXxl => pixel(screenWidth * 0.080);

  /// A size that lands on whole device pixels.
  ///
  /// A pixel font drawn at 13.4 logical points is a pixel font with blurred
  /// edges. Everything here is still derived from the screen (`docs/03`);
  /// this only snaps the result to the grid the glyphs were drawn on.
  double pixel(double size) {
    final double ratio = MediaQuery.of(this).devicePixelRatio;
    if (ratio <= 0) return size;

    return (size * ratio).roundToDouble() / ratio;
  }

  // Utility
  double get horizontalPadding => screenWidth * 0.05;
  double get cardBorderRadius => screenWidth * 0.03;
  bool get isSmallScreen => screenHeight < 700;
}
