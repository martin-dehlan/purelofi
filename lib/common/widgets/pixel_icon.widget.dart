import 'package:flutter/material.dart';

/// A pixel-art PNG, scaled without smoothing so the pixels stay square.
class PixelIcon extends StatelessWidget {
  const PixelIcon({required this.asset, required this.size, super.key});

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      child: AspectRatio(
        aspectRatio: 1,
        child: Image.asset(
          asset,
          filterQuality: FilterQuality.none,
          isAntiAlias: false,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
