import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../../../common/widgets/loading_dots.widget.dart';
import '../../../../common/widgets/skeleton.widget.dart';
import '../../../pro/controller/pro.controller.dart';
import '../../../pro/presentation/widgets/paywall_sheet.widget.dart';
import '../../controller/artist.controller.dart';
import 'artist_links_bar.widget.dart';
import 'support_artist_button.widget.dart';
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
  const ArtistSheet({required this.artistId, this.controller, super.key});

  final String artistId;

  /// The sheet's, when the page is a sheet of its own; none in the library.
  final ScrollController? controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final ArtistEntity? artist = ref.watch(artistByIdProvider(artistId));
    final List<TrackEntity> tracks = ref.watch(artistTracksProvider(artistId));
    final PlayerController player = ref.read(playerControllerProvider.notifier);

    if (artist == null) {
      final double avatar = context.screenWidth * 0.3;
      // While the artists load, the page's top in outline: the picture's
      // circle and the name's line, breathing.
      return Center(
        child: ref.watch(artistListControllerProvider).isLoading
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Skeleton(
                    width: avatar,
                    height: avatar,
                    borderRadius: BorderRadius.circular(avatar / 2),
                  ),
                  SizedBox(height: context.spaceM),
                  Skeleton(
                    width: avatar * 1.2,
                    height: context.fontXxl,
                    borderRadius: BorderRadius.circular(context.fontXxl / 4),
                  ),
                ],
              )
            : Text(
                'This artist is not on PureLofi any more.',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: context.fontS,
                ),
              ),
      );
    }

    void playAll() {
      if (tracks.isEmpty) return;
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

    final List<String> links = artist.links;
    final double avatar = context.screenWidth * 0.3;

    return CustomScrollView(
      controller: controller,
      slivers: <Widget>[
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
          sliver: SliverList.list(
            children: <Widget>[
              // The picture and the name centred; the channels stand beside
              // them on the right, over the header rather than in it, so
              // unfolding more channels moves neither.
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Center(
                        child: ArtistAvatar(artist: artist, size: avatar),
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
                    ],
                  ),
                  if (links.isNotEmpty)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: ArtistLinksBar(links: links, height: avatar),
                    ),
                ],
              ),
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
                        ? LoadingDots(
                            size: context.fontL,
                            color: cs.onSurfaceVariant,
                          )
                        : AppIcon(
                            AppGlyph.download,
                            size: context.fontL,
                            color: allDownloaded ? cs.primary : cs.onSurface,
                          ),
                  ),
                ],
              ),
              // Straight to the artist, when they take support (#152).
              if (artist.supportUrl != null) ...<Widget>[
                SizedBox(height: context.spaceM),
                SupportArtistButton(artist: artist),
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
                // It plays and the page stays open, as music apps keep the
                // list in hand while the music changes.
                onTap: () => unawaited(player.playTrack(track)),
              );
            },
          ),
        ),
        SliverPadding(padding: EdgeInsets.only(bottom: context.spaceXl)),
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
