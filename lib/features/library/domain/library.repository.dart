import '../../player/domain/track.entity.dart';
import 'import_report.dart';

/// The listener's own music (#66). Lives only on this device and is never
/// synced — the one part of the app Supabase knows nothing about.
///
/// Implementations throw `AppError` and nothing else.
abstract class LibraryRepository {
  /// Every imported track, newest first, and every change to them.
  Stream<List<TrackEntity>> watchTracks();

  Future<List<TrackEntity>> getTracks();

  /// Copies [sources] into the app. A file that cannot be imported is
  /// reported, not thrown: the others still arrive.
  Future<ImportReport> import(List<ImportSource> sources);

  /// Removes the track and its file. The listener's original is untouched —
  /// this was only ever a copy.
  Future<void> delete(String id);

  /// What the copies cost on disk.
  Future<int> sizeInBytes();
}
