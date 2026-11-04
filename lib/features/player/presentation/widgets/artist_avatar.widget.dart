import 'package:flutter/material.dart';

import '../../../../common/utils/app_fonts.dart';
import '../../domain/artist.entity.dart';
import 'cached_picture.widget.dart';

/// An artist's picture in a circle, or the first letter of their name until
/// there is one — and whenever the picture will not load. While it loads,
/// the circle breathes.
///
/// Always a circle: where the space it is given is narrower or lower than
/// [size] (a `ListTile` holds its leading widget to 56 px high), it shrinks
/// to fit instead of being squeezed into an oval.
class ArtistAvatar extends StatelessWidget {
  const ArtistAvatar({required this.artist, required this.size, super.key});

  final ArtistEntity artist;
  final double size;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) => Center(
      widthFactor: 1,
      heightFactor: 1,
      child: _circle(
        context,
        <double>[
          size,
          constraints.maxWidth,
          constraints.maxHeight,
        ].reduce((double a, double b) => a < b ? a : b),
      ),
    ),
  );

  Widget _circle(BuildContext context, double size) {
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
            : CachedPicture(
                url: url,
                decodeWidth: (size * MediaQuery.devicePixelRatioOf(context))
                    .round(),
                fallback: initial,
              ),
      ),
    );
  }
}
