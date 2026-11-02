import 'package:flutter/material.dart';

import '../../../../common/utils/responsive.dart';
import '../../domain/artist.entity.dart';
import 'artist_link_button.widget.dart';

/// The foot of an artist's page, where music apps keep the rest about them:
/// a few words if they wrote any, and every channel they are on. Below the
/// tracks, so the top of the page stays the picture, the name and Play.
///
/// Nothing at all when there is nothing to say.
class ArtistAbout extends StatelessWidget {
  const ArtistAbout({required this.artist, super.key});

  final ArtistEntity artist;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String? bio = artist.bio?.trim();
    final List<String> links = artist.links;
    final bool hasBio = bio != null && bio.isNotEmpty;
    if (!hasBio && links.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(context.spaceM),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(context.cardBorderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'About',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: context.fontL,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (hasBio) ...<Widget>[
            SizedBox(height: context.spaceS),
            Text(
              bio,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: context.fontM,
                height: 1.4,
              ),
            ),
          ],
          if (links.isNotEmpty) ...<Widget>[
            SizedBox(height: context.spaceM),
            Wrap(
              spacing: context.spaceS,
              runSpacing: context.spaceS,
              children: <Widget>[
                for (final String link in links) ArtistLinkButton(url: link),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
