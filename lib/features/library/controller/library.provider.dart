import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../common/database/daos/local_track.dao.dart';
import '../../player/controller/player.provider.dart';
import '../data/library.repository.impl.dart';
import '../data/tag_reader.service.impl.dart';
import '../data/track_picker.service.impl.dart';
import '../domain/library.repository.dart';
import '../domain/track_picker.service.dart';

part 'library.provider.g.dart';

/// Every provider for the library feature lives in this file (see `docs/05`).

/// Where the imported files live. Resolved in `main.dart`, because a
/// provider cannot wait for `path_provider`; tests override the repository
/// instead and never reach this.
@Riverpod(keepAlive: true)
Directory libraryDirectory(Ref ref) => throw UnimplementedError(
  'libraryDirectoryProvider must be overridden in main.dart',
);

@Riverpod(keepAlive: true)
LocalTrackDao localTrackDao(Ref ref) =>
    LocalTrackDao(ref.watch(appDatabaseProvider));

@Riverpod(keepAlive: true)
LibraryRepository libraryRepository(Ref ref) => LibraryRepositoryImpl(
  dao: ref.watch(localTrackDaoProvider),
  directory: ref.watch(libraryDirectoryProvider),
  tags: const TagReaderImpl(),
);

/// The system file picker. Overridden in widget tests, which cannot open it.
@Riverpod(keepAlive: true)
TrackPickerService trackPicker(Ref ref) => const TrackPickerServiceImpl();
