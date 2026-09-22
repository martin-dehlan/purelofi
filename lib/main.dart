import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'common/analytics/analytics.provider.dart';
import 'common/analytics/analytics.service.dart';
import 'common/config/env.dart';
import 'features/player/controller/player.provider.dart';
import 'features/player/data/audio_player.service.impl.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Env.load();
  // `publishableKey` is the current name for the slot the legacy anon key
  // occupies; `anonKey` is deprecated. The .env key stays SUPABASE_ANON_KEY.
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
  );

  // Starts the background playback service, which owns the notification and
  // the lock-screen controls for the whole app lifetime.
  final AudioPlayerServiceImpl audioHandler = await AudioService.init(
    builder: AudioPlayerServiceImpl.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'app.purelofi.audio',
      androidNotificationChannelName: 'PureLofi',
      // Android draws this as a silhouette — every opaque pixel turns white
      // and the colour is thrown away — so it is the wordmark's heart and
      // note, not the artwork, which would come out a white blob.
      androidNotificationIcon: 'drawable/ic_notification',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
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
      ],
      child: const PureLofiApp(),
    ),
  );
}
