import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/features/auth/controller/auth.provider.dart';
import 'package:purelofi/features/auth/domain/account.entity.dart';
import 'package:purelofi/features/player/controller/favorites_sync.controller.dart';
import 'package:purelofi/features/player/controller/player.provider.dart';
import 'package:purelofi/features/player/domain/favorites_sync.dart';

import '../../../helpers/fake_auth.repository.dart';

class _Device implements DeviceFavorites {
  int rounds = 0;
  int released = 0;

  @override
  Future<Map<String, bool>> pending() async {
    rounds++;
    return <String, bool>{};
  }

  @override
  Future<void> markSynced(Iterable<String> ids) async {}

  @override
  Future<void> apply(Set<String> accountIds) async {}

  @override
  Future<void> release() async => released++;
}

class _Account implements AccountFavorites {
  @override
  Future<Set<String>> fetchIds() async => <String>{};

  @override
  Future<void> add(String userId, Iterable<String> trackIds) async {}

  @override
  Future<void> remove(Iterable<String> trackIds) async {}
}

void main() {
  late FakeAuthRepository auth;
  late _Device device;

  ProviderContainer start({Account? signedIn}) {
    auth = FakeAuthRepository(signedIn: signedIn);
    device = _Device();
    final ProviderContainer c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        deviceFavoritesProvider.overrideWithValue(device),
        accountFavoritesProvider.overrideWithValue(_Account()),
      ],
    );
    addTearDown(c.dispose);
    addTearDown(auth.dispose);
    c.listen(favoritesSyncControllerProvider, (_, _) {}, fireImmediately: true);
    return c;
  }

  test('signed out, nothing ever syncs', () {
    fakeAsync((FakeAsync async) {
      final ProviderContainer c = start();
      async.flushMicrotasks();

      c.read(favoritesSyncControllerProvider.notifier).soon();
      async.elapse(const Duration(seconds: 5));

      expect(device.rounds, 0);
    });
  });

  test('a session from last time syncs on start', () {
    fakeAsync((FakeAsync async) {
      start(
        signedIn: const Account(id: 'u1', method: SignInMethod.email),
      );
      async.flushMicrotasks();

      expect(device.rounds, 1);
    });
  });

  test('a sign-in syncs at once', () {
    fakeAsync((FakeAsync async) {
      start();
      async.flushMicrotasks();

      auth.signInWithGoogle();
      async.flushMicrotasks();

      expect(device.rounds, 1);
    });
  });

  test('a burst of marks is one round, once things settle', () {
    fakeAsync((FakeAsync async) {
      final ProviderContainer c = start(
        signedIn: const Account(id: 'u1', method: SignInMethod.email),
      );
      async.flushMicrotasks();
      expect(device.rounds, 1);

      final FavoritesSyncController sync = c.read(
        favoritesSyncControllerProvider.notifier,
      );
      sync.soon();
      async.elapse(const Duration(milliseconds: 500));
      sync.soon();
      async.elapse(const Duration(milliseconds: 500));
      sync.soon();
      expect(device.rounds, 1);

      async.elapse(FavoritesSyncController.settle);

      expect(device.rounds, 2);
    });
  });

  test('signing out hands the marks back to the device', () {
    fakeAsync((FakeAsync async) {
      start(
        signedIn: const Account(id: 'u1', method: SignInMethod.email),
      );
      async.flushMicrotasks();

      auth.signOut();
      async.flushMicrotasks();

      expect(device.released, 1);
    });
  });
}
