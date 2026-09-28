import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/features/library/data/tag_reader.service.impl.dart';
import 'package:purelofi/features/library/domain/tag_reader.service.dart';

void main() {
  test('a file with no readable tags is none, not an error', () async {
    // The importer relies on this: it falls back to the file name.
    final Directory dir = await Directory.systemTemp.createTemp(
      'purelofi_tags',
    );
    addTearDown(() => dir.delete(recursive: true));
    final File junk = File('${dir.path}/junk.mp3')
      ..writeAsBytesSync(List<int>.generate(64, (int i) => i));

    final TrackTags tags = const TagReaderImpl().read(junk);

    expect(tags.title, isNull);
    expect(tags.artist, isNull);
    expect(tags.cover, isNull);
  });
}
