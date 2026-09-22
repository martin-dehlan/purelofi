import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'common/routes/app_router.dart';

/// Dark, and in the same pixel grid the scenes are drawn on.
///
/// The typeface is part of the art, not decoration: a rounded system face
/// over a pixel-art room reads as two apps stacked on each other. Pixelify
/// Sans keeps lowercase, which Silkscreen does not, so a track title stays a
/// title rather than a shout.
final ThemeData _theme = ThemeData.dark(useMaterial3: true).copyWith(
  textTheme: ThemeData.dark(
    useMaterial3: true,
  ).textTheme.apply(fontFamily: 'PixelifySans'),
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
