import 'package:go_router/go_router.dart';

import '../../../common/routes/app_routes.dart';
import 'screens/player.screen.dart';

/// The player owns its routes. There is no auth guard and no shell: the app
/// is one screen with a modal (see `docs/08`).
final List<RouteBase> playerRoutes = <RouteBase>[
  GoRoute(
    path: AppRoutes.player,
    builder: (_, _) => const PlayerScreen(),
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.trackPath,
        builder: (_, GoRouterState state) =>
            PlayerScreen(deepLinkTrackId: state.pathParameters['trackId']),
      ),
    ],
  ),
];
