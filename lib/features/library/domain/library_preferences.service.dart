import 'library_view.dart';

/// Where the library's order and sort are kept between launches.
abstract class LibraryPreferences {
  Future<LibraryView> load();

  Future<void> save(LibraryView view);
}
