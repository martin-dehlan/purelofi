import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'common/routes/app_router.dart';
import 'common/utils/app_fonts.dart';

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
final ThemeData _theme = ThemeData.dark(useMaterial3: true).copyWith(
  colorScheme: ThemeData.dark(useMaterial3: true).colorScheme.copyWith(
    primary: const Color(0xFFF0A05D),
    onPrimary: const Color(0xFF030308),
  ),
  textTheme: ThemeData.dark(
    useMaterial3: true,
  ).textTheme.apply(fontFamily: AppFonts.body),
);

/// The app shell. A lo-fi player is a night-time app, so it is dark by
/// default and the scene video stays the brightest thing on screen
/// (see `docs/09`).
class PureLofiApp extends ConsumerWidget {
  const PureLofiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'PureLofi',
      debugShowCheckedModeBanner: false,
      theme: _theme,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
