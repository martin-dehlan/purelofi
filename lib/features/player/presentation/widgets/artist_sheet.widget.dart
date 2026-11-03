import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/app_links.dart';
import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../../pro/controller/pro.controller.dart';
import '../../../pro/presentation/widgets/paywall_sheet.widget.dart';
import '../../controller/artist.controller.dart';
import '../../domain/artist_link.dart';
import '../../controller/downloads.controller.dart';
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

    final Downloads downloads =
        ref.watch(downloadsControllerProvider).value ?? const Downloads();
    final bool allDownloaded = tracks.isNotEmpty && tracks.every(downloads.has);
    final bool downloading = tracks.any(downloads.isLoading);

    void toggleDownloads() {
      if (!ref.read(downloadsOpenProvider)) {
        unawaited(showPaywallSheet(context, source: 'download'));
        return;
      }
      final DownloadsController downloader = ref.read(
        downloadsControllerProvider.notifier,
      );
      unawaited(
        allDownloaded ? downloader.remove(tracks) : downloader.download(tracks),
      );
    }

    final String? bio = artist.bio;
    final List<String> links = artist.links;

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
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton(
                      onPressed: tracks.isEmpty ? null : playAll,
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.onSurface,
                        foregroundColor: cs.surface,
                        minimumSize: Size.fromHeight(
                          context.screenHeight * 0.06,
                        ),
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
                  ),
                  SizedBox(width: context.spaceS),
                  // All of them for offline in one tap, the accent once
                  // they are all here.
                  IconButton.filledTonal(
                    tooltip: allDownloaded
                        ? 'Remove downloads'
                        : 'Download all',
                    onPressed: tracks.isEmpty || downloading
                        ? null
                        : toggleDownloads,
                    iconSize: context.fontL,
                    padding: EdgeInsets.all(context.spaceM),
                    style: IconButton.styleFrom(
                      backgroundColor: cs.surfaceContainerHigh,
                    ),
                    icon: downloading
                        ? SizedBox.square(
                            dimension: context.fontL,
                            child: CircularProgressIndicator(
                              strokeWidth: context.fontL * 0.12,
                              color: cs.onSurfaceVariant,
                            ),
                          )
                        : AppIcon(
                            AppGlyph.download,
                            size: context.fontL,
                            color: allDownloaded ? cs.primary : cs.onSurface,
                          ),
                  ),
                ],
              ),
              // Every channel they are on, by name: where to follow them
              // once a track has done its work.
              if (links.isNotEmpty) ...<Widget>[
                SizedBox(height: context.spaceM),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: context.spaceS,
                  runSpacing: context.spaceS,
                  children: <Widget>[
                    for (final String link in links)
                      ActionChip(
                        label: Text(artistLinkLabel(link)),
                        labelStyle: TextStyle(
                          color: cs.onSurface,
                          fontSize: context.fontS,
                        ),
                        backgroundColor: cs.surfaceContainerHigh,
                        side: BorderSide.none,
                        shape: const StadiumBorder(),
                        padding: EdgeInsets.symmetric(
                          horizontal: context.spaceS,
                          vertical: context.spaceXs,
                        ),
                        onPressed: () =>
                            unawaited(AppLinks.open(Uri.parse(link))),
                      ),
                  ],
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
