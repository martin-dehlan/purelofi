import 'dart:async';

import 'package:purelofi/features/player/domain/favorites.repository.dart';

/// Favourites in memory.
///
/// Widget tests use this rather than a real database: Drift schedules timers
/// of its own, and `testWidgets` fails a test that leaves one pending. What
/// the database actually does is covered by the DAO and repository tests.
class FakeFavoritesRepository implements FavoritesRepository {
  FakeFavoritesRepository([Set<String> initial = const <String>{}])
    : _ids = <String>{...initial} {
    _controller.add(<String>{..._ids});
  }

  final Set<String> _ids;
  final StreamController<Set<String>> _controller =
      StreamController<Set<String>>.broadcast();

  /// Every id that was ever toggled, in order — so a test can assert that a
  /// tap reached the repository at all.
  final List<String> toggled = <String>[];

  @override
  Stream<Set<String>> watchFavoriteIds() async* {
    yield <String>{..._ids};
    yield* _controller.stream;
  }

  @override
  Future<Set<String>> getFavoriteIds() async => <String>{..._ids};

  @override
  Future<bool> toggle(String trackId) async {
    toggled.add(trackId);
    final bool next = !_ids.contains(trackId);
    if (next) {
      _ids.add(trackId);
    } else {
      _ids.remove(trackId);
    }
    _controller.add(<String>{..._ids});

    return next;
  }

  void dispose() => _controller.close();
}
