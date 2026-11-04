import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'common/routes/app_router.dart';
import 'l10n/l10n.dart';
import 'common/utils/app_fonts.dart';
import 'features/player/controller/collections.controller.dart';
import 'features/player/controller/favorites_sync.controller.dart';
import 'features/player/controller/follows.controller.dart';
import 'features/player/controller/home_widget.controller.dart';
import 'features/player/controller/media_library.controller.dart';
import 'features/player/controller/mix.controller.dart';
import 'features/player/controller/new_content.controller.dart';
import 'features/player/controller/play_history.controller.dart';
import 'features/player/controller/room_music.controller.dart';

/// Dark, with quiet type.
///
/// The pixel art belongs to the rooms. Chrome that repeats it reads as a
/// costume, and Pixelify Sans across every label was exactly that. Karla is
/// plain and a little warm, so the text stays out of the scene's way; the
/// pixel face is kept for the wordmark alone (#67).
///
/// The one accent is the lamp: the warm light every room has, taken from the
/// scene palette (`assets/palette/purelofi.gpl`, Lamp #F0A05D). It marks what
/// is active — the track playing, the room you are in.
///
/// The rest of the scheme is grown from that same lamp by Material's tonal
/// palettes, so the containers behind a selected row or segment are a dim
/// warm tone that belongs with it, not Material's default violet. Neutral,
/// so the sheets stay near grey: a brown sheet over a blue room is mud.
final ColorScheme _scheme =
    ColorScheme.fromSeed(
      seedColor: const Color(0xFFF0A05D),
      brightness: Brightness.dark,
      dynamicSchemeVariant: DynamicSchemeVariant.neutral,
    ).copyWith(
      primary: const Color(0xFFF0A05D),
      onPrimary: const Color(0xFF030308),
    );

/// The app's theme, public so widget tests can render with it.
final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  colorScheme: _scheme,
  textTheme: ThemeData.dark(
    useMaterial3: true,
  ).textTheme.apply(fontFamily: AppFonts.body),
  // Every sheet in the app is a Material sheet: a handle to drag it by and
  // the low container tone, a step off the scene's darkest colours.
  bottomSheetTheme: BottomSheetThemeData(
    showDragHandle: true,
    backgroundColor: _scheme.surfaceContainerLow,
    dragHandleColor: _scheme.onSurfaceVariant,
  ),
  listTileTheme: ListTileThemeData(
    selectedColor: _scheme.primary,
    selectedTileColor: _scheme.secondaryContainer,
    iconColor: _scheme.onSurfaceVariant,
  ),
);

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
    // The room's mood, when the music follows the room (#143).
    ref.watch(roomMusicProvider);
    // Followed artists follow a signed-in listener too (#147).
    ref.watch(followSyncControllerProvider);
    // What Android Auto and other media browsers can open (#145).
    ref.watch(mediaLibraryProvider);
    // The home and lock screen widgets follow the room and the track (#144).
    ref.watch(homeWidgetSyncProvider);

    return MaterialApp.router(
      title: 'PureLofi',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      routerConfig: ref.watch(appRouterProvider),
      // Every string the listener reads comes from lib/l10n (#140).
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
