import 'package:flutter/material.dart';

import '../../../../common/utils/app_fonts.dart';
import '../../domain/artist.entity.dart';

/// An artist's picture in a circle, or the first letter of their name until
/// there is one — and whenever the picture will not load.
class ArtistAvatar extends StatelessWidget {
  const ArtistAvatar({required this.artist, required this.size, super.key});

  final ArtistEntity artist;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String name = artist.name.trim();
    final Widget initial = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: cs.surfaceContainerHighest,
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: TextStyle(
          color: cs.onSurface,
          fontFamily: AppFonts.wordmark,
          fontSize: size * 0.42,
        ),
      ),
    );
    final String? url = artist.avatarUrl;

    return ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: url == null
            ? initial
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => initial,
              ),
      ),
    );
  }
}
