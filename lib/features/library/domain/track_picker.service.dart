import 'import_report.dart';

/// The system's file picker, limited to audio.
abstract class TrackPickerService {
  /// The files the listener chose. Empty when they cancelled.
  Future<List<ImportSource>> pick();
}
