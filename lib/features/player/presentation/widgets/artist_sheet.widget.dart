import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/app_links.dart';
import '../../../../common/utils/responsive.dart';
import '../../controller/artist.controller.dart';
import '../../controller/player.controller.dart';
import '../../domain/artist.entity.dart';
import '../../domain/track.entity.dart';
import 'artist_avatar.widget.dart';
import 'music_sheet.dart';
import 'track_tile.widget.dart';

/// An artist's page: who they are, a way to hear all of them, where to find
/// more of their music, and their tracks.
///
/// The link out matters as much as the play button. The music is theirs,
/// and the page is as much a pointer to them as a list.
class ArtistSheet extends ConsumerWidget {
  const ArtistSheet({
    required this.artistId,
    required this.controller,
    super.key,
  });

  final String artistId;
  final ScrollController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final ArtistEntity? artist = ref.watch(artistByIdProvider(artistId));
    final List<TrackEntity> tracks = ref.watch(artistTracksProvider(artistId));
    final PlayerController player = ref.read(playerControllerProvider.notifier);

    if (artist == null) {
      return Center(
        child: ref.watch(artistListControllerProvider).isLoading
            ? const CircularProgressIndicator()
            : Text(
                'This artist is not on PureLofi any more.',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: context.fontS,
                ),
              ),
      );
    }

    // Back to the room, the way picking a track in the library goes.
    void backToRoom() =>
        Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);

    void playAll() {
      if (tracks.isEmpty) return;
      backToRoom();
      player.clearQueue();
      for (final TrackEntity track in tracks.skip(1)) {
        player.addToQueue(track);
      }
      unawaited(player.playTrack(tracks.first));
    }

    final String? bio = artist.bio;
    final String? link = artist.linkUrl;

    return CustomScrollView(
      controller: controller,
      slivers: <Widget>[
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
          sliver: SliverList.list(
            children: <Widget>[
              Center(
                child: ArtistAvatar(
                  artist: artist,
                  size: context.screenWidth * 0.3,
                ),
              ),
              SizedBox(height: context.spaceM),
              Text(
                artist.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: context.fontXxl,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: context.spaceS),
              Text(
                tracks.length == 1 ? '1 track' : '${tracks.length} tracks',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: context.fontS,
                ),
              ),
              if (bio != null && bio.trim().isNotEmpty) ...<Widget>[
                SizedBox(height: context.spaceM),
                Text(
                  bio,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: context.fontM,
                    height: 1.4,
                  ),
                ),
              ],
              SizedBox(height: context.spaceL),
              FilledButton(
                onPressed: tracks.isEmpty ? null : playAll,
                style: FilledButton.styleFrom(
                  backgroundColor: cs.onSurface,
                  foregroundColor: cs.surface,
                  minimumSize: Size.fromHeight(context.screenHeight * 0.06),
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  'Play',
                  style: TextStyle(
                    fontSize: context.fontM,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (link != null) ...<Widget>[
                SizedBox(height: context.spaceS),
                Center(
                  child: TextButton(
                    onPressed: () => unawaited(AppLinks.open(Uri.parse(link))),
                    style: TextButton.styleFrom(foregroundColor: cs.onSurface),
                    child: Text(
                      'More from ${artist.name}',
                      style: TextStyle(fontSize: context.fontM),
                    ),
                  ),
                ),
              ],
              SizedBox(height: context.spaceM),
            ],
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
          sliver: SliverList.builder(
            itemCount: tracks.length,
            itemBuilder: (BuildContext context, int index) {
              final TrackEntity track = tracks[index];
              return TrackTile(
                track: track,
                onTap: () {
                  backToRoom();
                  unawaited(player.playTrack(track));
                },
              );
            },
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: context.spaceXl)),
      ],
    );
  }
}

/// Opens the page of the artist with [artistId].
Future<void> showArtistSheet(BuildContext context, String artistId) =>
    showMusicSheet(
      context,
      (BuildContext context, ScrollController controller) =>
          ArtistSheet(artistId: artistId, controller: controller),
    );
