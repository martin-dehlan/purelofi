import 'package:flutter/material.dart';

import '../../../../common/utils/responsive.dart';
import 'artist_link_button.widget.dart';

/// An artist's channels as a small raised bar, centred at the foot of
/// their page under the tracks: a pill holding one mark per channel,
/// nothing else.
class ArtistLinksBar extends StatelessWidget {
  const ArtistLinksBar({required this.links, super.key});

  final List<String> links;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surfaceContainerHighest,
      elevation: 6,
      shadowColor: cs.shadow,
      shape: const StadiumBorder(),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: context.spaceXs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final String link in links) ArtistLinkButton(url: link),
          ],
        ),
      ),
    );
  }
}
