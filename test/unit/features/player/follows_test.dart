import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/common/database/app_database.dart';
import 'package:purelofi/common/database/daos/followed_artist.dao.dart';
import 'package:purelofi/features/player/data/follows.impl.dart';
import 'package:purelofi/features/player/domain/favorites_sync.dart';

import '../../../helpers/fake_follows.dart';

void main() {
  late AppDatabase database;
  late DeviceFollows device;

  setUp(() {
    database = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory()),
    );
    addTearDown(database.close);
    device = DeviceFollows(FollowedArtistDao(database));
  });

  test('follows and unfollows on the device', () async {
    await device.set('ada', followed: true);
    await device.set('kiko', followed: true);
    await device.set('kiko', followed: false);

    expect(await device.watchFollowed().first, <String>{'ada'});
    expect(await device.pending(), <String, bool>{'ada': true, 'kiko': false});
  });

  test('a sync round is a union on first sign-in, then a mirror', () async {
    final FakeAccountFollows account = FakeAccountFollows()
      ..ids.add('elsewhere');
    await device.set('here', followed: true);

    await syncFavorites(userId: 'u', device: device, account: account);

    expect(account.ids, <String>{'here', 'elsewhere'});
    expect(await device.watchFollowed().first, <String>{'here', 'elsewhere'});
    expect(await device.pending(), isEmpty);

    // Unfollowed on another device: it goes here too.
    account.ids.remove('elsewhere');
    await syncFavorites(userId: 'u', device: device, account: account);
    expect(await device.watchFollowed().first, <String>{'here'});
  });

  test(
    'an unfollow here, not yet pushed, is not undone by the account',
    () async {
      final FakeAccountFollows account = FakeAccountFollows();
      await device.set('ada', followed: true);
      await syncFavorites(userId: 'u', device: device, account: account);

      await device.set('ada', followed: false);
      await device.apply(<String>{'ada'});

      expect(await device.watchFollowed().first, isEmpty);
    },
  );
}
