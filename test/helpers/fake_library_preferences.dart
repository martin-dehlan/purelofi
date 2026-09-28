import 'package:purelofi/features/library/domain/library_preferences.service.dart';
import 'package:purelofi/features/library/domain/library_view.dart';

/// Order and sort kept in memory rather than the platform's store.
class FakeLibraryPreferences implements LibraryPreferences {
  FakeLibraryPreferences([this.stored = const LibraryView()]);

  LibraryView stored;
  int saves = 0;

  @override
  Future<LibraryView> load() async => stored;

  @override
  Future<void> save(LibraryView view) async {
    stored = view;
    saves++;
  }
}
