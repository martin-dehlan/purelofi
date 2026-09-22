import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'common/analytics/analytics.provider.dart';
import 'common/cache/media_cache.service.dart';
import 'common/analytics/analytics.service.dart';
import 'common/config/env.dart';
import 'common/database/app_database.dart';
import 'common/database/daos/cached_file.dao.dart';
import 'features/player/controller/player.provider.dart';
import 'features/player/data/audio_player.service.impl.dart';
import 'features/player/data/audio_session.source.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Env.load();
  // `publishableKey` is the current name for the slot the legacy anon key
  // occupies; `anonKey` is deprecated. The .env key stays SUPABASE_ANON_KEY.
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
  );

  // The files on disk. Built here because the cache directory and the
  // database both have to exist before anything asks for a track, and a
  // provider cannot wait.
  final AppDatabase database = AppDatabase();
  final MediaCache cache = FileMediaCache(
    dao: CachedFileDao(database),
    directory: await FileMediaCache.defaultDirectory(),
  );
  // Anything left over the limit by a previous run goes now, while nothing
  // is playing.
  unawaited(cache.evict());

  // What the platform says about calls, other players and the headphones.
  // `audio_service` configures the session; deciding what an interruption
  // means is ours.
  final AudioSessionInterruptions interruptions =
      await AudioSessionInterruptions.create();

  // Starts the background playback service, which owns the notification and
  // the lock-screen controls for the whole app lifetime.
  final AudioPlayerServiceImpl audioHandler = await AudioService.init(
    builder: () =>
        AudioPlayerServiceImpl(cache: cache, interruptions: interruptions),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'app.purelofi.audio',
      androidNotificationChannelName: 'PureLofi',
      // Android draws this as a silhouette — every opaque pixel turns white
      // and the colour is thrown away — so it is the wordmark's heart and
      // note, not the artwork, which would come out a white blob.
      androidNotificationIcon: 'drawable/ic_notification',
      // These two go together, and audio_service asserts it: an "ongoing"
      // notification is one Android will not let go of, so it is only
      // allowed if the service drops out of the foreground when paused.
      //
      // We want the opposite. Leaving the foreground lets Android kill the
      // process, and coming back to a cold start instead of a paused track
      // is the difference between a player and a toy. So the notification
      // stays put through a pause and is dismissible — which is what every
      // music app does anyway.
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: false,
    ),
  );

  // No key in .env means analytics stays off rather than crashing the app.
  final AnalyticsService analytics = await PostHogAnalyticsService.create();
  await analytics.appOpened();

  runApp(
    ProviderScope(
      overrides: [
        audioPlayerServiceProvider.overrideWithValue(audioHandler),
        analyticsServiceProvider.overrideWithValue(analytics),
        appDatabaseProvider.overrideWithValue(database),
        mediaCacheProvider.overrideWithValue(cache),
      ],
      child: const PureLofiApp(),
    ),
  );
}
