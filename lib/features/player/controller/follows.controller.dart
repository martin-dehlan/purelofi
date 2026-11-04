import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/controller/auth.controller.dart';
import '../../auth/domain/account.entity.dart';
import '../domain/favorites_sync.dart';
import 'player.provider.dart';

part 'follows.controller.g.dart';

/// The artists the listener follows (#147). Signed out they live on the
/// device; signed in they follow the account, the way favorites do.
@Riverpod(keepAlive: true)
class FollowsController extends _$FollowsController {
  @override
  Stream<Set<String>> build() =>
      ref.watch(deviceFollowsProvider).watchFollowed();

  Future<void> toggle(String artistId) async {
    final bool following = state.value?.contains(artistId) ?? false;
    await ref.read(deviceFollowsProvider).set(artistId, followed: !following);
    ref.read(followSyncControllerProvider.notifier).soon();
  }
}

/// Keeps a signed-in listener's follows the same on every device (#147),
/// with the same sync, triggers and rules as the favorites (#78).
@Riverpod(keepAlive: true)
class FollowSyncController extends _$FollowSyncController {
  static const Duration settle = Duration(milliseconds: 1500);

  Timer? _soon;
  bool _running = false;
  bool _again = false;

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
          ref.read(deviceFollowsProvider).release().catchError((Object _) {}),
        );
      }
    }, fireImmediately: true);

    return null;
  }

  void soon() {
    if (_signedIn == null) return;
    _soon?.cancel();
    _soon = Timer(settle, () => unawaited(_run()));
  }

  String? get _signedIn => ref.read(authControllerProvider).value?.id;

  Future<void> _run() async {
    final String? userId = _signedIn;
    if (userId == null) return;
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      await syncFavorites(
        userId: userId,
        device: ref.read(deviceFollowsProvider),
        account: ref.read(accountFollowsProvider),
      );
      state = DateTime.now();
    } on Object {
      // Offline, or the server said no: the follows stay pending.
    } finally {
      _running = false;
      if (_again) {
        _again = false;
        unawaited(_run());
      }
    }
  }
}
