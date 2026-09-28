import 'package:file_picker/file_picker.dart';

import '../domain/import_report.dart';
import '../domain/track_picker.service.dart';

/// The platform picker. Needs no permission on either platform: the system
/// UI hands over only what the listener chose (#66).
class TrackPickerServiceImpl implements TrackPickerService {
  const TrackPickerServiceImpl();

  @override
  Future<List<ImportSource>> pick() async {
    final List<PlatformFile> files = await FilePicker.pickFiles(
      type: FileType.audio,
    );

    return <ImportSource>[
      for (final PlatformFile file in files)
        ImportSource(name: file.name, open: () => file.xFile.openRead()),
    ];
  }
}
