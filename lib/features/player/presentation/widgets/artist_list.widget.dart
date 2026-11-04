import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/responsive.dart';
import '../../controller/artist.controller.dart';
import '../../domain/artist.entity.dart';
import 'artist_avatar.widget.dart';
import 'library_scope.widget.dart';
import '../../../../l10n/l10n.dart';

/// The library's artists pill: everyone with music in PureLofi, by name.
/// Tapping one opens their page.
class ArtistList extends ConsumerWidget {
  const ArtistList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final AsyncValue<List<ArtistEntity>> loaded = ref.watch(
      artistListControllerProvider,
    );
    final List<ArtistEntity> artists = ref.watch(playableArtistsProvider);

    if (artists.isEmpty) {
      final String? message = loaded.isLoading
          ? null
          : loaded.hasError
          ? context.l10n.artistsDidNotLoad
          : context.l10n.noArtistsYet;
      return SliverToBoxAdapter(
        child: message == null
            ? const SizedBox.shrink()
            : Text(
                message,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: context.fontS,
                  height: 1.5,
                ),
              ),
      );
    }

    return SliverList.builder(
      itemCount: artists.length,
      itemBuilder: (BuildContext context, int index) {
        final ArtistEntity artist = artists[index];
        final int count = ref.watch(artistTracksProvider(artist.id)).length;

        return ListTile(
          contentPadding: EdgeInsets.zero,
          horizontalTitleGap: context.spaceM,
          minVerticalPadding: context.spaceS,
          leading: ArtistAvatar(
            artist: artist,
            size: context.screenWidth * 0.13,
          ),
          title: Text(
            artist.name,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: context.fontM,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            context.l10n.trackCount(count),
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: context.fontS,
            ),
          ),
          onTap: () => unawaited(openArtistPage(context, artist.id)),
        );
      },
    );
  }
}
