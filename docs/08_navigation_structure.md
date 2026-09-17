# Navigation Structure (go_router)

**TL;DR:** go_router with Riverpod integration. **No auth guard, no bottom-nav
`ShellRoute`** — PureLofi's MVP is effectively a single `PlayerScreen` with a
modal. go_router is kept anyway for one reason: deep linking (from the YouTube
channel / `purelofi.app`) works out of the box and Phase 2 will add routes.

> **MVP deviation from the wine-app lineage:** the wine app had splash/login/
> register + a 3-tab shell. PureLofi has none of that — no login, one screen.
> Do not build an `AppShell`, `NavigationBar`, or auth `redirect`.

---

## Setup

```yaml
# pubspec.yaml
dependencies:
  go_router: ^14.x.x
```

---

## AppRoutes (path constants)

File: `lib/common/routes/app_routes.dart`

```dart
abstract class AppRoutes {
  static const String player = '/';           // the whole app
  static const String track  = '/track/:trackId';   // deep link to a track (BTS)
}
```

---

## Feature Route Definitions

File: `lib/features/player/presentation/player.routes.dart`

```dart
import 'package:go_router/go_router.dart';
import 'screens/player.screen.dart';

final playerRoutes = [
  GoRoute(
    path: AppRoutes.player,
    builder: (context, state) => const PlayerScreen(),
    routes: [
      // Deep link: /track/:trackId opens the player with that track's BTS modal.
      GoRoute(
        path: 'track/:trackId',
        builder: (context, state) => PlayerScreen(
          deepLinkTrackId: state.pathParameters['trackId'],
        ),
      ),
    ],
  ),
];
```

---

## GoRouter Config (with Riverpod)

File: `lib/common/routes/app_router.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: AppRoutes.player,
    debugLogDiagnostics: true,
    // NO redirect — public app, no auth.
    routes: [
      ...playerRoutes,
    ],
  );
}
```

---

## Navigation in Code

```dart
// Open a track deep link (rare — mostly external)
context.go('/track/$trackId');

// Pop a modal
context.pop();
```

Most in-app navigation is **not** routing at all — switching scenes and tracks
mutates player state (see `docs/05`), it does not push routes. The BTS view is a
modal bottom sheet (`showModalBottomSheet`), not a route.

---

## Deep Linking

go_router handles deep linking automatically. Configure the custom scheme so
`purelofi.app` / YouTube links can open a specific track:

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<intent-filter>
  <action android:name="android.intent.action.VIEW"/>
  <category android:name="android.intent.category.DEFAULT"/>
  <category android:name="android.intent.category.BROWSABLE"/>
  <data android:scheme="purelofi" android:host="app"/>
</intent-filter>
```

```xml
<!-- ios/Runner/Info.plist -->
<key>FlutterDeepLinkingEnabled</key><true/>
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array><string>purelofi</string></array>
  </dict>
</array>
```

Incoming link `purelofi://app/track/abc123` maps to `/track/abc123`.
(Universal/App Links for `https://purelofi.app/...` can be added later.)

---

## App Entry Point

```dart
// lib/main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );
  // audio_service init happens here too (see SPEC / player controller).
  runApp(const ProviderScope(child: PureLofiApp()));
}

// lib/app.dart
class PureLofiApp extends ConsumerWidget {
  const PureLofiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      routerConfig: router,
      title: 'PureLofi',
      theme: AppTheme.dark,   // lo-fi player defaults to a dark theme
    );
  }
}
```

---

## Rules Checklist

- [ ] All route paths defined as constants in `AppRoutes`
- [ ] The player feature owns its `player.routes.dart`
- [ ] **No** auth `redirect`, **no** `ShellRoute`, **no** `NavigationBar`
- [ ] Scene/track switching mutates state — it does not push routes
- [ ] BTS is a modal bottom sheet, not a route
- [ ] Deep link scheme is `purelofi` (not the old app's scheme)
