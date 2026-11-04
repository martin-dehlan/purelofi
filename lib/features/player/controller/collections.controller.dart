import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/controller/auth.controller.dart';
import '../../auth/domain/account.entity.dart';
import '../../library/controller/library.provider.dart';
import '../domain/mood.entity.dart';
import '../domain/playback_scope.dart';
import '../domain/playlist.entity.dart';
import '../domain/playlist_sync.dart';
import '../domain/track.entity.dart';
import 'player.provider.dart';
import 'track.controller.dart';

part 'collections.controller.g.dart';

/// PureLofi's moods (#141). None when there are none, or none could be
/// loaded: the library simply shows no moods row.
@Riverpod(keepAlive: true)
Future<List<MoodEntity>> moods(Ref ref) async {
  try {
    return await ref.watch(moodRepositoryProvider).getMoods();
  } on Object {
    return const <MoodEntity>[];
  }
}

/// The listener's playlists, most recently changed first (#141).
@Riverpod(keepAlive: true)
Stream<List<PlaylistEntity>> playlists(Ref ref) =>
    ref.watch(playlistRepositoryProvider).watchPlaylists();

/// The list the stream is held to, or `null` for everything (#141).
@Riverpod(keepAlive: true)
class PlaybackScopeController extends _$PlaybackScopeController {
  @override
  PlaybackScope? build() => null;

  void select(PlaybackScope? scope) => state = scope;
}

/// The tracks of [scope] that can be played, in its order. A track gone
/// from the catalogue, or a file of the listener's on another device, is
/// left out.
Future<List<TrackEntity>> scopeTracks(Ref ref, PlaybackScope scope) async {
  final Map<String, TrackEntity> catalogue = <String, TrackEntity>{
    for (final TrackEntity t in await ref.read(
      trackListControllerProvider.future,
    ))
      t.id: t,
  };

  switch (scope.kind) {
    case ScopeKind.mood:
      final List<MoodEntity> all = await ref.read(moodsProvider.future);
      final MoodEntity? mood = all
          .where((MoodEntity m) => m.id == scope.id)
          .firstOrNull;
      return <TrackEntity>[
        for (final String id in mood?.trackIds ?? const <String>[])
          ?catalogue[id],
      ];
    case ScopeKind.playlist:
      // Straight from the store: a stream provider read with no one
      // listening may never deliver.
      final List<PlaylistEntity> all = await ref
          .read(playlistRepositoryProvider)
          .watchPlaylists()
          .first;
      final PlaylistEntity? playlist = all
          .where((PlaylistEntity p) => p.id == scope.id)
          .firstOrNull;
      if (playlist == null) return const <TrackEntity>[];
      final Map<String, TrackEntity> local = <String, TrackEntity>{
        if (playlist.items.any(
          (PlaylistItem i) => i.source == TrackSource.local,
        ))
          for (final TrackEntity t
              in await ref.read(libraryRepositoryProvider).getTracks())
            t.id: t,
      };
      return <TrackEntity>[
        for (final PlaylistItem item in playlist.items)
          ?(item.source == TrackSource.local ? local : catalogue)[item.trackId],
      ];
  }
}

/// [scopeTracks] for the screen: computed again when the playlist, the
/// moods or the catalogue change.
@riverpod
Future<List<TrackEntity>> scopeTrackList(Ref ref, PlaybackScope scope) async {
  ref
    ..watch(trackListControllerProvider)
    ..watch(moodsProvider)
    ..watch(playlistsProvider);
  try {
    return await scopeTracks(ref, scope);
  } on Object {
    return const <TrackEntity>[];
  }
}

/// Keeps a signed-in listener's playlists the same on every device (#141),
/// the way favorites are kept (#78): on sign-in, and shortly after each
/// change. Signed out it does nothing; the playlists live on the device.
@Riverpod(keepAlive: true)
class PlaylistSyncController extends _$PlaylistSyncController {
  static const Duration settle = Duration(milliseconds: 1500);

  Timer? _soon;
  bool _running = false;
  bool _again = false;

  @override
  DateTime? build() {
    ref.onDispose(() => _soon?.cancel());

    ref.listen<AsyncValue<Account?>>(authControllerProvider, (
      AsyncValue<Account?>? previous,
      AsyncValue<Account?> next,
    ) {
      final String? now = next.value?.id;
      if (now != null && now != previous?.value?.id) unawaited(_run());
    }, fireImmediately: true);

    ref.listen<int>(playlistChangesProvider, (_, _) => _scheduleSoon());

    return null;
  }

  void _scheduleSoon() {
    if (_signedIn == null) return;
    _soon?.cancel();
    _soon = Timer(settle, () => unawaited(_run()));
  }

  String? get _signedIn => ref.read(authControllerProvider).value?.id;

  Future<void> _run() async {
    final String? userId = _signedIn;
    if (userId == null) return;
    if (_running) {
      _again = true;
      return;
    }

    _running = true;
    try {
      await syncPlaylists(
        userId: userId,
        device: ref.read(devicePlaylistsProvider),
        account: ref.read(accountPlaylistsProvider),
      );
      state = DateTime.now();
    } on Object {
      // Offline, or the server said no: the changes stay unsynced.
    } finally {
      _running = false;
      if (_again) {
        _again = false;
        unawaited(_run());
      }
    }
  }
}
