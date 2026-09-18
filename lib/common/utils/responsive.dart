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

  // Font sizes (width-based)
  double get fontXs => screenWidth * 0.025;
  double get fontS => screenWidth * 0.032;
  double get fontM => screenWidth * 0.040;
  double get fontL => screenWidth * 0.050;
  double get fontXl => screenWidth * 0.065;
  double get fontXxl => screenWidth * 0.080;

  // Utility
  double get horizontalPadding => screenWidth * 0.05;
  double get cardBorderRadius => screenWidth * 0.03;
  bool get isSmallScreen => screenHeight < 700;
}
