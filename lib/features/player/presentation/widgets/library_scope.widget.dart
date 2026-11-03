import 'package:flutter/widgets.dart';

import 'artist_sheet.widget.dart';

/// Marks what is inside the library, so an artist picked there opens in
/// the library, sliding in over the list, rather than as a sheet on top.
class LibraryScope extends InheritedWidget {
  const LibraryScope({
    required this.openArtist,
    required super.child,
    super.key,
  });

  /// Slides the artist's page in over the library.
  final void Function(String artistId) openArtist;

  static LibraryScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<LibraryScope>();

  @override
  bool updateShouldNotify(LibraryScope oldWidget) => false;
}

/// Opens the page of the artist with [artistId]: inside the library when
/// [context] is in it, as its own sheet anywhere else.
Future<void> openArtistPage(BuildContext context, String artistId) async {
  final LibraryScope? scope = LibraryScope.maybeOf(context);
  if (scope != null) return scope.openArtist(artistId);

  return showArtistSheet(context, artistId);
}
