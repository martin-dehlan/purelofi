import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/common/database/app_database.dart';
import 'package:purelofi/common/database/daos/track.dao.dart';
import 'package:purelofi/features/player/data/device_favorites.impl.dart';
import 'package:purelofi/features/player/data/favorites.repository.impl.dart';
import 'package:purelofi/features/player/domain/favorites_sync.dart';

/// The account in memory: what Supabase's `user_favorites` would hold for
/// one listener.
class _Account implements AccountFavorites {
  final Set<String> ids = <String>{};
  bool offline = false;

  void _check() {
    if (offline) throw Exception('SocketException: offline');
  }

  @override
  Future<Set<String>> fetchIds() async {
    _check();
    return <String>{...ids};
  }

  @override
  Future<void> add(String userId, Iterable<String> trackIds) async {
    _check();
    ids.addAll(trackIds);
  }

  @override
  Future<void> remove(Iterable<String> trackIds) async {
    _check();
    ids.removeAll(trackIds);
  }
}

/// One phone: its own database, its own marks.
class _Device {
  _Device(List<String> catalogue) {
    database = AppDatabase.forTesting(
      DatabaseConnection(NativeDatabase.memory()),
    );
    dao = TrackDao(database);
    favorites = FavoritesRepositoryImpl(dao: dao);
    device = DeviceFavoritesImpl(dao);
    _catalogue = catalogue;
  }

  late final AppDatabase database;
  late final TrackDao dao;
  late final FavoritesRepositoryImpl favorites;
  late final DeviceFavoritesImpl device;
  late final List<String> _catalogue;

  Future<void> load() => dao.replaceTracks(<TrackTableCompanion>[
    for (final String id in _catalogue)
      TrackTableCompanion.insert(
        id: id,
        title: id,
        audioUrl: 'https://example.com/$id.mp3',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
  ]);

  Future<Set<String>> marks() => favorites.getFavoriteIds();

  Future<void> sync(_Account account) =>
      syncFavorites(userId: 'u1', device: device, account: account);
}

void main() {
  const List<String> catalogue = <String>['a', 'b', 'c', 'd'];
  late _Account account;
  late _Device phone;
  late _Device tablet;

  setUp(() async {
    account = _Account();
    phone = _Device(catalogue);
    tablet = _Device(catalogue);
    addTearDown(phone.database.close);
    addTearDown(tablet.database.close);
    await phone.load();
    await tablet.load();
  });

  test('a mark on one device shows on the other', () async {
    await phone.favorites.toggle('a');
    await phone.sync(account);

    await tablet.sync(account);

    expect(account.ids, <String>{'a'});
    expect(await tablet.marks(), <String>{'a'});
  });

  test('an unmark travels too', () async {
    await phone.favorites.toggle('a');
    await phone.sync(account);
    await tablet.sync(account);

    await tablet.favorites.toggle('a');
    await tablet.sync(account);
    await phone.sync(account);

    expect(account.ids, isEmpty);
    expect(await phone.marks(), isEmpty);
  });

  test('the first sign-in merges, losing nothing on either side', () async {
    account.ids.addAll(<String>{'a', 'b'});
    // Marked on this phone while signed out.
    await phone.favorites.toggle('c');

    await phone.sync(account);

    expect(account.ids, <String>{'a', 'b', 'c'});
    expect(await phone.marks(), <String>{'a', 'b', 'c'});
  });

  test('offline marks wait, then go up once the network is back', () async {
    account.offline = true;
    await phone.favorites.toggle('d');
    await expectLater(phone.sync(account), throwsA(anything));
    expect(await phone.marks(), <String>{'d'});

    account.offline = false;
    await phone.sync(account);

    expect(account.ids, <String>{'d'});
  });

  test('a pending mark wins over the account\'s older copy', () async {
    account.ids.add('a');
    await phone.sync(account);
    expect(await phone.marks(), <String>{'a'});

    // Unmarked here, still on the account: the newer choice is the device's.
    await phone.favorites.toggle('a');
    await phone.sync(account);

    expect(account.ids, isEmpty);
    expect(await phone.marks(), isEmpty);
  });

  test(
    'after sign-out the marks stay, and the next sign-in takes them',
    () async {
      await phone.favorites.toggle('a');
      await phone.sync(account);

      await phone.device.release();
      expect(await phone.marks(), <String>{'a'});

      // Signing in to a different, empty account keeps them and uploads them.
      final _Account other = _Account();
      await phone.sync(other);

      expect(other.ids, <String>{'a'});
      expect(await phone.marks(), <String>{'a'});
    },
  );

  test('a content refresh does not lose the sync state', () async {
    await phone.favorites.toggle('b');
    await phone.load(); // the catalogue is fetched again
    await phone.sync(account);

    expect(account.ids, <String>{'b'});
  });
}
