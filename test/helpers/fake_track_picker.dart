import 'package:purelofi/features/library/domain/import_report.dart';
import 'package:purelofi/features/library/domain/track_picker.service.dart';

/// The system picker, answered by the test instead of a person.
class FakeTrackPicker implements TrackPickerService {
  FakeTrackPicker([this.names = const <String>[]]);

  /// What the "listener" picks next. Empty means they cancelled.
  List<String> names;

  @override
  Future<List<ImportSource>> pick() async => <ImportSource>[
    for (final String name in names)
      ImportSource(
        name: name,
        open: () => Stream<List<int>>.value(const <int>[0]),
      ),
  ];
}
