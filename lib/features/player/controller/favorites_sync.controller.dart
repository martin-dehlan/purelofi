import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/controller/auth.controller.dart';
import '../../auth/domain/account.entity.dart';
import '../domain/favorites_sync.dart';
import 'player.provider.dart';

part 'favorites_sync.controller.g.dart';

/// Keeps a signed-in listener's favorites the same on every device (#78).
///
/// Runs on sign-in (which is also app start with a session from last time),
/// and shortly after each mark — a burst of taps is one round, not ten.
/// Signed out it does nothing at all: favorites then simply live on the
/// device, as they always have.
///
/// A round that fails (no network, mostly) is not an error anyone sees: the
/// marks stay pending and the next round takes them along.
@Riverpod(keepAlive: true)
class FavoritesSyncController extends _$FavoritesSyncController {
  /// How long after a tap the round starts.
  static const Duration settle = Duration(milliseconds: 1500);

  Timer? _soon;
  bool _running = false;
  bool _again = false;

  /// When the last round finished, for anyone who wants to know.
  @override
  DateTime? build() {
    ref.onDispose(() => _soon?.cancel());

    ref.listen<AsyncValue<Account?>>(authControllerProvider, (
      AsyncValue<Account?>? previous,
      AsyncValue<Account?> next,
    ) {
      final String? was = previous?.value?.id;
      final String? now = next.value?.id;
      if (now == was) return;

      if (now != null) {
        unawaited(_run());
      } else if (was != null) {
        _soon?.cancel();
        unawaited(
          ref.read(deviceFavoritesProvider).release().catchError((Object _) {}),
        );
      }
    }, fireImmediately: true);

    return null;
  }

  /// A mark changed: sync once things have settled.
  void soon() {
    if (_signedIn == null) return;
    _soon?.cancel();
    _soon = Timer(settle, () => unawaited(_run()));
  }

  String? get _signedIn => ref.read(authControllerProvider).value?.id;

  Future<void> _run() async {
    final String? userId = _signedIn;
    if (userId == null) return;
    // One round at a time; a change during a round earns one more after it.
    if (_running) {
      _again = true;
      return;
    }

    _running = true;
    try {
      await syncFavorites(
        userId: userId,
        device: ref.read(deviceFavoritesProvider),
        account: ref.read(accountFavoritesProvider),
      );
      state = DateTime.now();
    } on Object {
      // Offline, or the server said no: the marks stay pending.
    } finally {
      _running = false;
      if (_again) {
        _again = false;
        unawaited(_run());
      }
    }
  }
}
