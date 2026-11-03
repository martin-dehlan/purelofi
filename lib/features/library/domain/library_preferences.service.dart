import 'library_view.dart';

/// Where the library's sort is kept between launches.
abstract class LibraryPreferences {
  Future<LibraryView> load();

  Future<void> save(LibraryView view);
}
