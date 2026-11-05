import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'common/routes/app_router.dart';
import 'l10n/l10n.dart';
import 'common/theme/app_palette.dart';
import 'common/theme/app_theme.dart';
import 'features/player/controller/collections.controller.dart';
import 'features/player/controller/favorites_sync.controller.dart';
import 'features/player/controller/follows.controller.dart';
import 'features/player/controller/home_widget.controller.dart';
import 'features/player/controller/media_library.controller.dart';
import 'features/player/controller/language.controller.dart';
import 'features/player/controller/palette.controller.dart';
import 'features/player/controller/mix.controller.dart';
import 'features/player/controller/new_content.controller.dart';
import 'features/player/controller/play_history.controller.dart';
import 'features/player/controller/wake_alarm.controller.dart';

/// The app shell. A lo-fi player is a night-time app, so it is dark by
/// default and the scene video stays the brightest thing on screen
/// (see `docs/09`).
class PureLofiApp extends ConsumerWidget {
  const PureLofiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Built once at the root so a session from last time syncs favorites on
    // start, before anyone opens the library (#78).
    ref.watch(favoritesSyncControllerProvider);
    // The listening log follows the player from the first track on (#142).
    ref.watch(playHistoryRecorderProvider);
    // Rooms stepped into and tracks played stop being marked new (#148).
    ref.watch(newContentMarkerProvider);
    // The listener's mix, and the room's sounds from the first second (#136).
    ref.watch(mixControllerProvider);
    // Playlists follow a signed-in listener to every device (#141).
    ref.watch(playlistSyncControllerProvider);
    // Followed artists follow a signed-in listener too (#147).
    ref.watch(followSyncControllerProvider);
    // What Android Auto and other media browsers can open (#145).
    ref.watch(mediaLibraryProvider);
    // The home and lock screen widgets follow the room and the track (#144).
    ref.watch(homeWidgetSyncProvider);
    // The wake-up alarm, set again on every launch and answered when it
    // rings (#146).
    ref.watch(wakeAlarmControllerProvider);

    return MaterialApp.router(
      title: 'PureLofi',
      debugShowCheckedModeBanner: false,
      // The accent picked in the settings, lamp until one is.
      theme: AppTheme.of(
        ref.watch(paletteControllerProvider).value ?? AppPalette.lamp,
      ),
      routerConfig: ref.watch(appRouterProvider),
      // Every string the listener reads comes from lib/l10n (#140).
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // The phone's language unless one was picked in the settings.
      locale: switch (ref.watch(languageControllerProvider).value) {
        final String code => Locale(code),
        null => null,
      },
    );
  }
}
