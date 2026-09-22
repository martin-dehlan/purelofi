import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';
import '../database/daos/cached_file.dao.dart';

/// Keeps the files a scene needs on this device.
///
/// Behind an interface because the renderer and the player must be testable
/// without a disk or a network (see `docs/10`).
abstract class MediaCache {
  /// The local file for [url] if it has been downloaded, else `null`.
  ///
  /// A hit also counts as a use, which is what keeps a track that is played
  /// every evening from being evicted.
  Future<File?> fileFor(String url);

  /// Downloads [url] unless it is already here. Returns the local file, or
  /// `null` when the download failed — a cache miss is never an error the
  /// listener should see.
  Future<File?> store(String url);

  /// How much disk the cache is using.
  Future<int> sizeInBytes();

  /// Throws away the least recently used files until the cache fits.
  Future<void> evict();
}

/// A [MediaCache] on the filesystem, with Drift as its index.
class FileMediaCache implements MediaCache {
  FileMediaCache({
    required CachedFileDao dao,
    required Directory directory,
    http.Client? client,
    this.maxBytes = defaultMaxBytes,
    DateTime Function()? now,
  }) : _dao = dao,
       _directory = directory,
       _client = client ?? http.Client(),
       _now = now ?? DateTime.now;

  /// 256 MB. A three-minute track is a few megabytes and a scene's sprites
  /// under ten, so this holds a long evening's worth without the app turning
  /// into the largest thing on a phone.
  static const int defaultMaxBytes = 256 * 1024 * 1024;

  final CachedFileDao _dao;
  final Directory _directory;
  final http.Client _client;
  final DateTime Function() _now;
  final int maxBytes;

  /// Downloads in flight, so two layers asking for the same strip at the same
  /// moment fetch it once.
  final Map<String, Future<File?>> _inFlight = <String, Future<File?>>{};

  @override
  Future<File?> fileFor(String url) async {
    final CachedFileTableData? row = await _dao.find(url);
    if (row == null) return null;

    final File file = File('${_directory.path}/${row.fileName}');
    if (!file.existsSync()) {
      // The index outlived the file — a wiped cache directory, an OS that
      // reclaimed the space. Forget it rather than hand back a dead path.
      await _dao.forget(url);
      return null;
    }

    await _dao.touch(url, _now());

    return file;
  }

  @override
  Future<File?> store(String url) {
    return _inFlight.putIfAbsent(url, () async {
      try {
        return await _download(url);
      } finally {
        // remove() hands back the future we are inside; ignoring it marks it
        // handled here without hiding anything from the caller.
        _inFlight.remove(url)?.ignore();
      }
    });
  }

  Future<File?> _download(String url) async {
    final File? existing = await fileFor(url);
    if (existing != null) return existing;

    final List<int>? bytes = await _fetch(url);
    if (bytes == null) return null;

    if (!_directory.existsSync()) _directory.createSync(recursive: true);

    final String fileName = _fileNameFor(url);
    final File file = File('${_directory.path}/$fileName');

    // Written beside and then renamed: a half-downloaded file that the app
    // died in the middle of must never be served as if it were whole.
    final File temporary = File('${file.path}.part');
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.rename(file.path);

    await _dao.remember(
      url: url,
      fileName: fileName,
      sizeBytes: bytes.length,
      now: _now(),
    );
    await evict();

    return file;
  }

  Future<List<int>?> _fetch(String url) async {
    try {
      final http.Response response = await _client.get(Uri.parse(url));
      if (response.statusCode >= 300) return null;

      return response.bodyBytes;
    } on Object {
      // No network, a bad host, a truncated response: all the same answer.
      // The caller falls back to streaming.
      return null;
    }
  }

  @override
  Future<int> sizeInBytes() => _dao.totalBytes();

  @override
  Future<void> evict() async {
    int total = await _dao.totalBytes();
    if (total <= maxBytes) return;

    for (final CachedFileTableData row in await _dao.oldestFirst()) {
      if (total <= maxBytes) return;

      final File file = File('${_directory.path}/${row.fileName}');
      if (file.existsSync()) {
        try {
          await file.delete();
        } on Object {
          // A file the OS will not let go of stays; its row goes, so the
          // cache stops counting on it.
        }
      }

      await _dao.forget(row.url);
      total -= row.sizeBytes;
    }
  }

  /// A name derived from the URL, so the same file is never fetched twice and
  /// nothing on disk depends on a server's idea of a filename.
  static String _fileNameFor(String url) {
    final String digest = sha1.convert(url.codeUnits).toString();
    final int dot = url.lastIndexOf('.');
    final String extension = dot > url.lastIndexOf('/') && dot != -1
        ? url.substring(dot)
        : '';

    return '$digest$extension';
  }

  /// Where the cache lives: support rather than documents, because these are
  /// files the app can always fetch again and the user never sees.
  static Future<Directory> defaultDirectory() async {
    final Directory support = await getApplicationSupportDirectory();

    return Directory('${support.path}/media_cache');
  }
}
