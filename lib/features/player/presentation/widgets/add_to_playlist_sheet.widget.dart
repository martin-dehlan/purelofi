import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../../../common/widgets/menu_row.widget.dart';
import '../../controller/collections.controller.dart';
import '../../controller/player.provider.dart';
import '../../domain/playlist.entity.dart';
import '../../domain/track.entity.dart';
import 'playlist_name_dialog.dart';
import '../../../../l10n/l10n.dart';

/// Picks the playlist [track] goes into, or makes a new one for it (#141).
class AddToPlaylistSheet extends ConsumerWidget {
  const AddToPlaylistSheet({required this.track, super.key});

  final TrackEntity track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<PlaylistEntity> playlists =
        ref.watch(playlistsProvider).value ?? const <PlaylistEntity>[];
    final PlaylistRepository repository = ref.read(playlistRepositoryProvider);
    final PlaylistItem item = PlaylistItem(
      trackId: track.id,
      source: track.source,
    );

    Future<void> into(String id) async {
      await repository.add(id, item);
      if (context.mounted) Navigator.of(context).pop();
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              context.l10n.addToPlaylist,
              style: TextStyle(
                fontSize: context.fontL,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: context.spaceS),
            MenuRow(
              glyph: AppGlyph.add,
              title: context.l10n.newPlaylist,
              onTap: () async {
                final String? name = await askPlaylistName(context);
                if (name == null) return;
                await into(await repository.create(name));
              },
            ),
            for (final PlaylistEntity playlist in playlists)
              MenuRow(
                glyph: AppGlyph.queue,
                title: playlist.name,
                subtitle: context.l10n.trackCount(playlist.items.length),
                onTap: () => unawaited(into(playlist.id)),
              ),
            SizedBox(height: context.spaceM),
          ],
        ),
      ),
    );
  }
}

Future<void> showAddToPlaylistSheet(BuildContext context, TrackEntity track) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => AddToPlaylistSheet(track: track),
    );
