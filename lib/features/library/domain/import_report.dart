import '../../player/domain/track.entity.dart';

/// One file the listener picked, not yet copied into the app.
///
/// Read through [open] rather than a path: on Android a picked file can be a
/// content URI with no path at all.
class ImportSource {
  const ImportSource({required this.name, required this.open});

  /// The file's name as the listener sees it, extension included.
  final String name;

  final Stream<List<int>> Function() open;
}

/// A file that was not imported, and why, in words for the listener.
class RejectedImport {
  const RejectedImport({required this.name, required this.reason});

  final String name;
  final String reason;
}

/// What one import did. Partial success is normal: pick ten files, one of
/// them a PDF, and nine arrive.
class ImportReport {
  const ImportReport({required this.imported, required this.rejected});

  final List<TrackEntity> imported;
  final List<RejectedImport> rejected;
}
