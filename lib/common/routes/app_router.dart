import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/player/presentation/player.routes.dart';
import 'app_routes.dart';

part 'app_router.g.dart';

/// No redirect: the app is public, there is nothing to guard.
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  return GoRouter(initialLocation: AppRoutes.player, routes: playerRoutes);
}
