import 'dart:async';

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../common/cache/media_cache.service.dart';
import '../../../common/config/supabase.provider.dart';
import '../../../common/database/app_database.dart';
import '../../../common/database/daos/artist.dao.dart';
import '../../../common/database/daos/cached_file.dao.dart';
import '../../../common/database/daos/followed_artist.dao.dart';
import '../../../common/database/daos/mood.dao.dart';
import '../../../common/database/daos/playlist.dao.dart';
import '../../../common/database/daos/play_event.dao.dart';
import '../../../common/database/daos/scene.dao.dart';
import '../../../common/database/daos/seen_item.dao.dart';
import '../../../common/database/daos/track.dao.dart';
import '../data/follows.impl.dart';
import '../data/home_widget.service.impl.dart';
import '../data/wake_alarm_store.impl.dart';
import '../data/wake_scheduler.impl.dart';
import '../data/screen_awake.service.impl.dart';
import '../data/mix_preferences.service.impl.dart';
import '../data/mood.repository.impl.dart';
import '../data/playlist.repository.impl.dart';
import '../data/playlists.api.dart';
import '../data/new_content.repository.impl.dart';
import '../data/play_history.repository.impl.dart';
import '../data/content.api.dart';
import '../data/content.repository.impl.dart';
import '../data/device_favorites.impl.dart';
import '../data/favorites.api.dart';
import '../data/display_preferences.service.impl.dart';
import '../data/focus_notifier.service.impl.dart';
import '../data/favorites.repository.impl.dart';
import '../data/playback_preferences.service.impl.dart';
import '../data/sprite_loader.service.dart';
import '../domain/focus_notifier.service.dart';
import '../domain/home_widget.service.dart';
import '../domain/wake_alarm.dart';
import '../domain/mix_preferences.service.dart';
import '../domain/screen_awake.service.dart';
import '../domain/mood.entity.dart';
import '../domain/playlist.entity.dart';
import '../domain/playlist_sync.dart';
import '../domain/new_content.dart';
import '../domain/play_history.repository.dart';
import '../domain/audio_player.service.dart';
import '../domain/content.repository.dart';
import '../domain/display_preferences.service.dart';
import '../domain/favorites.repository.dart';
import '../domain/favorites_sync.dart';
import '../domain/playback_preferences.service.dart';
import '../domain/track.entity.dart';
import '../domain/scene.entity.dart';

part 'player.provider.g.dart';

/// Every provider for the player feature lives in this file (see `docs/05`).

@Riverpod(keepAlive: true)
ContentApi contentApi(Ref ref) => ContentApi(ref.watch(supabaseClientProvider));

/// The local mirror of the content. Kept alive and closed with the app: a
/// database opened twice is a database locked against itself.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final AppDatabase database = AppDatabase();
  ref.onDispose(database.close);

  return database;
}

@Riverpod(keepAlive: true)
TrackDao trackDao(Ref ref) => TrackDao(ref.watch(appDatabaseProvider));

@Riverpod(keepAlive: true)
CachedFileDao cachedFileDao(Ref ref) =>
    CachedFileDao(ref.watch(appDatabaseProvider));

/// The files on disk.
///
/// `null` until the cache directory has been resolved, and `null` forever in
/// tests that do not override it — everything that uses it treats a missing
/// cache as "stream it", which is exactly the MVP behaviour.
@Riverpod(keepAlive: true)
MediaCache? mediaCache(Ref ref) => null;

/// A scene's cover on this device: downloaded the first time anything asks,
/// then read from disk — so the scene list draws its pictures at once, even
/// offline. `null` when there is no cache or the download failed; the caller
/// then falls back to the network.
@Riverpod(keepAlive: true)
Future<File?> sceneCover(Ref ref, String url) async =>
    ref.watch(mediaCacheProvider)?.store(url);

/// Any picture on this device — a track's cover, an artist's photo:
/// downloaded the first time it is shown, then read from disk, so the
/// second time it is there at once. `null` without a cache or when the
/// download failed; the picture then comes from the network.
@Riverpod(keepAlive: true)
Future<File?> pictureFile(Ref ref, String url) async =>
    ref.watch(mediaCacheProvider)?.store(url);

@Riverpod(keepAlive: true)
SceneDao sceneDao(Ref ref) => SceneDao(ref.watch(appDatabaseProvider));

@Riverpod(keepAlive: true)
FavoritesRepository favoritesRepository(Ref ref) =>
    FavoritesRepositoryImpl(dao: ref.watch(trackDaoProvider));

/// The account's favorites (#78). Only ever called while signed in.
@Riverpod(keepAlive: true)
AccountFavorites accountFavorites(Ref ref) =>
    FavoritesApi(ref.watch(supabaseClientProvider));

@Riverpod(keepAlive: true)
DeviceFavorites deviceFavorites(Ref ref) =>
    DeviceFavoritesImpl(ref.watch(trackDaoProvider));

@Riverpod(keepAlive: true)
ContentRepository contentRepository(Ref ref) {
  final ContentRepositoryImpl repository = ContentRepositoryImpl(
    api: ref.watch(contentApiProvider),
    trackDao: ref.watch(trackDaoProvider),
    sceneDao: ref.watch(sceneDaoProvider),
    artistDao: ref.watch(artistDaoProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
}

@Riverpod(keepAlive: true)
ArtistDao artistDao(Ref ref) => ArtistDao(ref.watch(appDatabaseProvider));

@Riverpod(keepAlive: true)
PlayEventDao playEventDao(Ref ref) =>
    PlayEventDao(ref.watch(appDatabaseProvider));

/// The listening log on this device (#142). Overridden in widget tests with
/// one in memory, like every other table.
@Riverpod(keepAlive: true)
PlayHistoryRepository playHistoryRepository(Ref ref) =>
    PlayHistoryRepositoryImpl(ref.watch(playEventDaoProvider));

/// The wake-up alarm with the platform (#146). Asks at start whether the
/// alarm is what opened the app.
@Riverpod(keepAlive: true)
WakeScheduler wakeScheduler(Ref ref) {
  final WakeSchedulerImpl scheduler = WakeSchedulerImpl();
  unawaited(scheduler.checkLaunch());
  return scheduler;
}

/// Where the alarm is kept (#146).
@Riverpod(keepAlive: true)
WakeAlarmStore wakeAlarmStore(Ref ref) => WakeAlarmStoreImpl();

/// The home and lock screen widgets (#144).
@Riverpod(keepAlive: true)
HomeWidgetService homeWidgetService(Ref ref) => HomeWidgetServiceImpl();

/// Keeps the screen on in window mode (#149).
@Riverpod(keepAlive: true)
ScreenAwake screenAwake(Ref ref) => const ScreenAwakeImpl();

/// The artists the listener follows, on the device (#147).
@Riverpod(keepAlive: true)
DeviceFollows deviceFollows(Ref ref) =>
    DeviceFollows(FollowedArtistDao(ref.watch(appDatabaseProvider)));

/// The account's follows (#147).
@Riverpod(keepAlive: true)
AccountFavorites accountFollows(Ref ref) =>
    FollowsApi(ref.watch(supabaseClientProvider));

/// PureLofi's moods (#141), with an offline copy.
@Riverpod(keepAlive: true)
MoodRepository moodRepository(Ref ref) => MoodRepositoryImpl(
  client: ref.watch(supabaseClientProvider),
  dao: MoodDao(ref.watch(appDatabaseProvider)),
);

/// The listener's playlists on this device (#141). Every change nudges the
/// sync, which does nothing while signed out.
@Riverpod(keepAlive: true)
PlaylistRepositoryImpl playlistStore(Ref ref) => PlaylistRepositoryImpl(
  PlaylistDao(ref.watch(appDatabaseProvider)),
  onChange: () => ref.read(playlistChangesProvider.notifier).changed(),
);

@Riverpod(keepAlive: true)
PlaylistRepository playlistRepository(Ref ref) =>
    ref.watch(playlistStoreProvider);

@Riverpod(keepAlive: true)
DevicePlaylists devicePlaylists(Ref ref) => ref.watch(playlistStoreProvider);

@Riverpod(keepAlive: true)
AccountPlaylists accountPlaylists(Ref ref) =>
    PlaylistsApi(ref.watch(supabaseClientProvider));

/// Counts playlist changes, for the sync to follow without the repository
/// knowing about it.
@Riverpod(keepAlive: true)
class PlaylistChanges extends _$PlaylistChanges {
  @override
  int build() => 0;

  void changed() => state++;
}

/// The listener's mix of music and room sounds (#136, #154).
@Riverpod(keepAlive: true)
MixPreferences mixPreferences(Ref ref) => MixPreferencesImpl();

/// What the listener has met, for the "new" marks (#148). Overridden in
/// widget tests with one in memory.
@Riverpod(keepAlive: true)
NewContentRepository newContentRepository(Ref ref) =>
    NewContentRepositoryImpl(dao: SeenItemDao(ref.watch(appDatabaseProvider)));

/// Where shuffle and repeat are remembered. Overridden in tests with one in
/// memory.
@Riverpod(keepAlive: true)
PlaybackPreferences playbackPreferences(Ref ref) => PlaybackPreferencesImpl();

/// Where the player's look is kept: for now, whether the controls hide.
@Riverpod(keepAlive: true)
DisplayPreferences displayPreferences(Ref ref) => DisplayPreferencesImpl();

/// How the focus timer reaches a listener who is not looking (#137).
/// Overridden in tests with one in memory.
@Riverpod(keepAlive: true)
FocusNotifier focusNotice(Ref ref) => FocusNotifierImpl();

/// Builds the widget that renders a scene's video.
typedef SceneVideoBuilder = Widget Function(SceneEntity scene);

/// Builds the widget that renders a behind-the-scenes clip.
typedef BtsVideoBuilder = Widget Function(String videoUrl);

/// Test seam for the scene video surface.
///
/// `video_player` talks to platform channels, so widget tests override this
/// with a no-op builder rather than rendering a real video (see `docs/10`).
/// `null` means "use the real player".
@riverpod
SceneVideoBuilder? sceneVideoBuilder(Ref ref) => null;

/// The audio player.
///
/// `audio_service` has to be initialised before the app starts, so `main.dart`
/// creates the handler and overrides this provider with it. Tests override it
/// with a fake.
@Riverpod(keepAlive: true)
AudioPlayerService audioPlayerService(Ref ref) => throw UnimplementedError(
  'audioPlayerServiceProvider must be overridden in main.dart',
);

/// Test seam for the behind-the-scenes video surface, for the same reason as
/// [sceneVideoBuilderProvider]. `null` means "use the real player".
@riverpod
BtsVideoBuilder? btsVideoBuilder(Ref ref) => null;

/// One track by id, for the `/track/:trackId` deep link.
@riverpod
Future<TrackEntity?> trackDetail(Ref ref, String trackId) =>
    ref.watch(contentRepositoryProvider).getTrackById(trackId);

/// Loads the sprite strips the scene renderer draws.
///
/// Overridden in widget tests with a loader that returns generated images,
/// so no test touches the network.
@Riverpod(keepAlive: true)
SpriteLoader spriteLoader(Ref ref) {
  final SpriteLoader loader = NetworkSpriteLoader(
    cache: ref.watch(mediaCacheProvider),
  );
  ref.onDispose(loader.dispose);
  return loader;
}
