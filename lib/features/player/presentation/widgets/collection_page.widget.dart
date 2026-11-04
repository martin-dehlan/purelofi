import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import '../../controller/collections.controller.dart';
import '../../controller/player.controller.dart';
import '../../controller/player.provider.dart';
import '../../domain/playback_scope.dart';
import '../../domain/playlist.entity.dart';
import '../../domain/track.entity.dart';
import 'playlist_name_dialog.dart';
import 'track_tile.widget.dart';
import '../../../../l10n/l10n.dart';

/// The tracks of [scope] (#141), a mood or one of the listener's playlists:
/// a Play button, the tracks in order, and for a playlist the means to
/// reorder, remove, rename and delete.
class CollectionPage extends ConsumerWidget {
  const CollectionPage({required this.scope, required this.onGone, super.key});

  final PlaybackScope scope;

  /// Called after the playlist is deleted, to slide the page away.
  final VoidCallback onGone;

  bool get _isPlaylist => scope.kind == ScopeKind.playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final PlayerController player = ref.read(playerControllerProvider.notifier);
    final PlaylistRepository playlists = ref.read(playlistRepositoryProvider);
    final List<TrackEntity> tracks =
        ref.watch(scopeTrackListProvider(scope)).value ?? const <TrackEntity>[];
    final EdgeInsets padding = EdgeInsets.symmetric(
      horizontal: context.horizontalPadding,
    );

    final Widget header = Padding(
      padding: EdgeInsets.symmetric(vertical: context.spaceS),
      child: Row(
        children: <Widget>[
          FilledButton.icon(
            onPressed: tracks.isEmpty
                ? null
                : () => unawaited(player.playScope(scope)),
            icon: AppIcon(
              AppGlyph.play,
              size: context.fontM,
              color: tracks.isEmpty ? cs.onSurfaceVariant : cs.onPrimary,
            ),
            label: Text(context.l10n.play),
          ),
          const Spacer(),
          if (_isPlaylist) ...<Widget>[
            IconButton(
              tooltip: context.l10n.renamePlaylist,
              onPressed: () async {
                final String? name = await askPlaylistName(
                  context,
                  initial: scope.title,
                  title: context.l10n.renamePlaylist,
                  action: context.l10n.rename,
                );
                if (name != null) await playlists.rename(scope.id, name);
              },
              icon: AppIcon(AppGlyph.more, size: context.fontL),
            ),
            IconButton(
              tooltip: context.l10n.deletePlaylist,
              onPressed: () async {
                if (!await confirmDeletePlaylist(context, scope.title)) return;
                await playlists.delete(scope.id);
                onGone();
              },
              icon: AppIcon(AppGlyph.remove, size: context.fontL),
            ),
          ],
        ],
      ),
    );

    if (tracks.isEmpty) {
      return ListView(
        padding: padding,
        children: <Widget>[
          header,
          Text(
            _isPlaylist ? context.l10n.emptyPlaylist : context.l10n.emptyMood,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: context.fontS,
            ),
          ),
        ],
      );
    }

    Widget tile(int index) => TrackTile(
      track: tracks[index],
      onTap: () => unawaited(player.playScope(scope, start: tracks[index])),
    );

    if (!_isPlaylist) {
      return ListView.builder(
        padding: padding,
        itemCount: tracks.length + 1,
        itemBuilder: (BuildContext context, int i) =>
            i == 0 ? header : tile(i - 1),
      );
    }

    // A playlist reorders by dragging, and a row swiped away leaves it.
    return ReorderableListView.builder(
      padding: padding,
      header: header,
      itemCount: tracks.length,
      onReorderItem: (int from, int to) =>
          unawaited(playlists.move(scope.id, from, to)),
      itemBuilder: (BuildContext context, int index) => Dismissible(
        key: ValueKey<String>('${tracks[index].id}@$index'),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => unawaited(playlists.removeAt(scope.id, index)),
        background: ColoredBox(
          color: cs.errorContainer,
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(
              padding: EdgeInsets.all(context.spaceM),
              child: AppIcon(
                AppGlyph.remove,
                size: context.fontL,
                color: cs.onErrorContainer,
              ),
            ),
          ),
        ),
        child: tile(index),
      ),
    );
  }
}
