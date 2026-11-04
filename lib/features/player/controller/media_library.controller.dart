import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../pro/controller/pro.controller.dart';
import '../domain/media_library.dart';
import '../domain/mood.entity.dart';
import '../domain/playback_scope.dart';
import '../domain/playlist.entity.dart';
import '../domain/scene.entity.dart';
import '../domain/track.entity.dart';
import 'collections.controller.dart';
import 'player.controller.dart';
import 'player.provider.dart';
import 'scene.controller.dart';
import 'track.controller.dart';

part 'media_library.controller.g.dart';

/// What Android Auto and other media browsers see of PureLofi (#145):
/// rooms, favorites, moods and playlists, each playable from the car.
/// Built at the root, so the car finds it as soon as the app runs.
@Riverpod(keepAlive: true)
AppMediaLibrary mediaLibrary(Ref ref) {
  final AppMediaLibrary library = AppMediaLibrary(ref);
  ref.read(audioPlayerServiceProvider).setLibrary(library);
  return library;
}

class AppMediaLibrary implements MediaLibrary {
  AppMediaLibrary(this._ref);

  final Ref _ref;

  @override
  Future<List<BrowseNode>> children(String parentId) async {
    switch (parentId) {
      case BrowseIds.root:
        final List<MoodEntity> moods = await _moods();
        final List<PlaylistEntity> playlists = await _playlists();
        return <BrowseNode>[
          const BrowseNode(id: BrowseIds.rooms, title: 'Rooms'),
          const BrowseNode(id: BrowseIds.favorites, title: 'Favorites'),
          if (moods.isNotEmpty)
            const BrowseNode(id: BrowseIds.moods, title: 'Moods'),
          if (playlists.isNotEmpty)
            const BrowseNode(id: BrowseIds.playlists, title: 'Playlists'),
        ];
      case BrowseIds.rooms:
        // A room plays the music in it, with its cover on the car's screen.
        return <BrowseNode>[
          for (final SceneEntity scene in await _scenes())
            if (!_ref.read(lockedScenesProvider).contains(scene.id))
              BrowseNode(
                id: BrowseIds.room(scene.id),
                title: scene.title,
                artUri: _uri(scene.thumbnailUrl),
                playable: true,
              ),
        ];
      case BrowseIds.favorites:
        return <BrowseNode>[
          for (final TrackEntity track in await _favorites())
            BrowseNode(
              id: BrowseIds.track(track.id),
              title: track.title,
              subtitle: track.artistName,
              artUri: _uri(track.coverUrl),
              playable: true,
            ),
        ];
      case BrowseIds.moods:
        return <BrowseNode>[
          for (final MoodEntity mood in await _moods())
            BrowseNode(
              id: BrowseIds.mood(mood.id),
              title: mood.title,
              artUri: _uri(mood.coverUrl),
              playable: true,
            ),
        ];
      case BrowseIds.playlists:
        return <BrowseNode>[
          for (final PlaylistEntity p in await _playlists())
            BrowseNode(
              id: BrowseIds.playlist(p.id),
              title: p.name,
              subtitle: p.items.length == 1
                  ? '1 track'
                  : '${p.items.length} tracks',
              playable: true,
            ),
        ];
    }
    return const <BrowseNode>[];
  }

  @override
  Future<void> play(String id) async {
    final (String, String)? parsed = BrowseIds.parse(id);
    if (parsed == null) return;
    final (String kind, String key) = parsed;
    final PlayerController player = _ref.read(
      playerControllerProvider.notifier,
    );

    switch (kind) {
      case 'room':
        final SceneEntity? scene = (await _scenes())
            .where((SceneEntity s) => s.id == key)
            .firstOrNull;
        if (scene == null) return;
        _ref.read(activeSceneControllerProvider.notifier).switchTo(scene);
        if (_ref.read(playerControllerProvider).currentTrack == null) {
          await player.playNext();
        } else if (!_ref.read(playerControllerProvider).isPlaying) {
          await player.togglePlayPause();
        }
      case 'track':
        final TrackEntity? track = (await _ref.read(
          trackListControllerProvider.future,
        )).where((TrackEntity t) => t.id == key).firstOrNull;
        if (track != null) await player.playTrack(track);
      case 'mood':
        final MoodEntity? mood = (await _moods())
            .where((MoodEntity m) => m.id == key)
            .firstOrNull;
        if (mood == null) return;
        await player.playScope(
          PlaybackScope(kind: ScopeKind.mood, id: mood.id, title: mood.title),
        );
      case 'playlist':
        final PlaylistEntity? p = (await _playlists())
            .where((PlaylistEntity p) => p.id == key)
            .firstOrNull;
        if (p == null) return;
        await player.playScope(
          PlaybackScope(kind: ScopeKind.playlist, id: p.id, title: p.name),
        );
    }
  }

  Future<List<SceneEntity>> _scenes() =>
      _ref.read(sceneListControllerProvider.future);

  Future<List<MoodEntity>> _moods() async {
    try {
      return await _ref.read(moodsProvider.future);
    } on Object {
      return const <MoodEntity>[];
    }
  }

  Future<List<PlaylistEntity>> _playlists() async {
    try {
      return await _ref.read(playlistRepositoryProvider).watchPlaylists().first;
    } on Object {
      return const <PlaylistEntity>[];
    }
  }

  Future<List<TrackEntity>> _favorites() async {
    Set<String> marked;
    try {
      // From the store: a stream provider read with no one listening may
      // never deliver.
      marked = await _ref.read(favoritesRepositoryProvider).getFavoriteIds();
    } on Object {
      marked = const <String>{};
    }
    final List<TrackEntity> all = await _ref.read(
      trackListControllerProvider.future,
    );
    return all.where((TrackEntity t) => marked.contains(t.id)).toList();
  }

  static Uri? _uri(String? url) => url == null ? null : Uri.tryParse(url);
}
