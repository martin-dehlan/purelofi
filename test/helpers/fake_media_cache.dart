import 'dart:io';

import 'package:purelofi/common/cache/media_cache.service.dart';

/// A cache that hands back a file without touching the network.
class FakeMediaCache implements MediaCache {
  FakeMediaCache({this.file, this.size = 0});

  /// What [store] and [fileFor] return. `null` stands for a failed download.
  final File? file;

  final List<String> stored = <String>[];

  /// What [sizeInBytes] reports; [clear] empties it.
  int size;
  bool cleared = false;

  @override
  Future<File?> fileFor(String url) async => file;

  @override
  Future<File?> store(String url) async {
    stored.add(url);

    return file;
  }

  @override
  Future<int> sizeInBytes() async => size;

  @override
  Future<void> evict() async {}

  @override
  Future<void> clear() async {
    cleared = true;
    size = 0;
  }
}
