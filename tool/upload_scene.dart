// Uploads a scene folder to Supabase: sprite strips to storage, layer rows
// to the database.
//
//   dart run tool/upload_scene.dart --scene rainy_room --dir ~/Desktop/rainy_room
//   dart run tool/upload_scene.dart --scene rainy_room --dir ./art --dry-run
//
// The folder contract lives in lib/.../scene_manifest.dart and is documented
// in docs/12. This tool uses that same parser, so the rules cannot drift.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:purelofi/features/player/data/scene_manifest.dart';

Future<void> main(List<String> args) async {
  final _Args parsed;
  try {
    parsed = _Args.parse(args);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln(_usage);
    exit(64);
  }

  try {
    await _run(parsed);
  } on _UploadException catch (error) {
    stderr.writeln('\n✗ ${error.message}');
    exit(1);
  } on SceneManifestException catch (error) {
    stderr.writeln('\n✗ ${error.message}');
    exit(1);
  }
}

const String _usage = '''
Usage: dart run tool/upload_scene.dart --scene <slug> --dir <folder> [--dry-run]

  --scene    Stable handle for the scene, e.g. rainy_room
  --dir      Folder holding the sprite strips and scene.json
  --dry-run  Validate and print, upload nothing
''';

const String _bucket = 'scenes';

class _UploadException implements Exception {
  const _UploadException(this.message);
  final String message;
}

class _Args {
  const _Args({required this.scene, required this.dir, required this.dryRun});

  final String scene;
  final Directory dir;
  final bool dryRun;

  static _Args parse(List<String> args) {
    String? scene;
    String? dir;
    bool dryRun = false;

    for (int i = 0; i < args.length; i++) {
      switch (args[i]) {
        case '--scene':
          scene = i + 1 < args.length ? args[++i] : null;
        case '--dir':
          dir = i + 1 < args.length ? args[++i] : null;
        case '--dry-run':
          dryRun = true;
        case '--help' || '-h':
          stdout.writeln(_usage);
          exit(0);
        default:
          throw FormatException('Unknown argument: ${args[i]}');
      }
    }

    if (scene == null || scene.isEmpty) {
      throw const FormatException('Missing --scene');
    }
    if (dir == null || dir.isEmpty) {
      throw const FormatException('Missing --dir');
    }

    return _Args(
      scene: scene,
      dir: Directory(_expandHome(dir)),
      dryRun: dryRun,
    );
  }
}

String _expandHome(String path) {
  if (!path.startsWith('~')) return path;

  final String? home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  return home == null ? path : path.replaceFirst('~', home);
}

Future<void> _run(_Args args) async {
  if (!args.dir.existsSync()) {
    throw _UploadException('No such folder: ${args.dir.path}');
  }

  final _Env env = _Env.load();

  // 1. Read the folder through the app's own parser.
  final File sceneJson = File('${args.dir.path}/scene.json');
  if (!sceneJson.existsSync()) {
    throw _UploadException('No scene.json in ${args.dir.path}');
  }

  final List<File> pngs =
      args.dir
          .listSync()
          .whereType<File>()
          .where((File f) => f.path.endsWith('.png'))
          .toList()
        ..sort((File a, File b) => a.path.compareTo(b.path));

  if (pngs.isEmpty) {
    throw _UploadException('No .png files in ${args.dir.path}');
  }

  final SceneManifest manifest = SceneManifest.parse(
    sceneJson: sceneJson.readAsStringSync(),
    spriteFileNames: pngs.map(_baseName).toList(),
  );

  // 2. Check each strip really holds the frames its name claims.
  final Map<String, File> filesByName = <String, File>{
    for (final File file in pngs) _baseName(file): file,
  };

  stdout.writeln('Scene "${manifest.title}" (${args.scene})');
  stdout.writeln(
    'Canvas ${manifest.canvasWidth}x${manifest.canvasHeight}, '
    '${manifest.layers.length} layers',
  );

  for (final (SpriteFileName file, LayerManifest settings) in manifest.layers) {
    final File png = filesByName[file.fileName]!;
    final (int width, int height) = _pngSize(png);

    if (width % file.frameCount != 0) {
      throw _UploadException(
        '${file.fileName}: ${width}px wide does not divide into '
        '${file.frameCount} frames',
      );
    }

    final int frameWidth = width ~/ file.frameCount;
    stdout.writeln(
      '  ${file.zIndex.toString().padLeft(2, '0')}  ${file.name.padRight(16)} '
      '${frameWidth}x$height x${file.frameCount}'
      '${settings.fps > 0 ? ' @${settings.fps}fps' : ''}'
      '${settings.tiles ? ' tiling' : ''}'
      '${settings.onlyWhilePlaying ? ' while-playing' : ''}',
    );
  }

  if (args.dryRun) {
    stdout.writeln('\n--dry-run: nothing uploaded.');
    return;
  }

  // 3. Upload the sprites.
  stdout.writeln('\nUploading to storage/$_bucket/${args.scene}/');
  final Map<String, String> spriteUrls = <String, String>{};

  for (final (SpriteFileName file, _) in manifest.layers) {
    final String path = '${args.scene}/${file.fileName}';
    await _uploadSprite(env, path, filesByName[file.fileName]!);
    spriteUrls[file.fileName] =
        '${env.url}/storage/v1/object/public/$_bucket/$path';
    stdout.writeln('  ${file.fileName}');
  }

  // 4. Upsert the scene, then replace its layers.
  final String sceneId = await _upsertScene(env, args.scene, manifest);
  await _replaceLayers(env, sceneId, manifest, spriteUrls);

  stdout.writeln(
    '\n✓ ${manifest.layers.length} layers live. '
    'Scene id $sceneId',
  );
}

String _baseName(File file) => file.path.split(Platform.pathSeparator).last;

/// Reads width and height straight out of the PNG header, so the tool needs
/// no image library.
(int, int) _pngSize(File file) {
  final List<int> bytes = file.openSync().readSync(24);
  if (bytes.length < 24) {
    throw _UploadException('${_baseName(file)} is not a readable PNG');
  }

  const List<int> signature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
  for (int i = 0; i < signature.length; i++) {
    if (bytes[i] != signature[i]) {
      throw _UploadException('${_baseName(file)} is not a PNG');
    }
  }

  int readInt(int offset) =>
      (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];

  return (readInt(16), readInt(20));
}

class _Env {
  const _Env({required this.url, required this.serviceRoleKey});

  final String url;
  final String serviceRoleKey;

  Map<String, String> get headers => <String, String>{
    'apikey': serviceRoleKey,
    'Authorization': 'Bearer $serviceRoleKey',
  };

  /// Reads .env directly — this runs outside Flutter, so dotenv is not
  /// available.
  static _Env load() {
    final File file = File('.env');
    if (!file.existsSync()) {
      throw const _UploadException(
        'No .env in the current folder. Run this from the repo root.',
      );
    }

    final Map<String, String> values = <String, String>{};
    for (final String line in file.readAsLinesSync()) {
      final String trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      final int separator = trimmed.indexOf('=');
      if (separator <= 0) continue;

      values[trimmed.substring(0, separator).trim()] = trimmed
          .substring(separator + 1)
          .trim();
    }

    final String url = values['SUPABASE_URL'] ?? '';
    final String key = values['SUPABASE_SERVICE_ROLE_KEY'] ?? '';

    if (url.isEmpty) throw const _UploadException('SUPABASE_URL is not set');
    if (key.isEmpty) {
      throw const _UploadException(
        'SUPABASE_SERVICE_ROLE_KEY is not set — uploading needs it, the anon '
        'key is read-only',
      );
    }

    return _Env(url: url, serviceRoleKey: key);
  }
}

Future<void> _uploadSprite(_Env env, String path, File file) async {
  final Uri uri = Uri.parse('${env.url}/storage/v1/object/$_bucket/$path');
  final http.Response response = await http.post(
    uri,
    headers: <String, String>{
      ...env.headers,
      'Content-Type': 'image/png',
      // Re-uploading the same scene replaces its sprites.
      'x-upsert': 'true',
    },
    body: file.readAsBytesSync(),
  );

  if (response.statusCode >= 300) {
    throw _UploadException(
      'Upload of $path failed (${response.statusCode}): ${response.body}',
    );
  }
}

Future<String> _upsertScene(
  _Env env,
  String slug,
  SceneManifest manifest,
) async {
  final http.Response response = await http.post(
    Uri.parse('${env.url}/rest/v1/scenes?on_conflict=slug'),
    headers: <String, String>{
      ...env.headers,
      'Content-Type': 'application/json',
      'Prefer': 'resolution=merge-duplicates,return=representation',
    },
    body: jsonEncode(<String, Object?>{
      'slug': slug,
      'title': manifest.title,
      // Layered scenes have no video; the column stays non-null.
      'video_url': '',
      'canvas_width': manifest.canvasWidth,
      'canvas_height': manifest.canvasHeight,
      'is_active': true,
    }),
  );

  if (response.statusCode >= 300) {
    throw _UploadException(
      'Saving the scene failed (${response.statusCode}): ${response.body}',
    );
  }

  final List<dynamic> rows = jsonDecode(response.body) as List<dynamic>;
  return (rows.first as Map<String, dynamic>)['id'] as String;
}

Future<void> _replaceLayers(
  _Env env,
  String sceneId,
  SceneManifest manifest,
  Map<String, String> spriteUrls,
) async {
  // Replace rather than merge: a layer removed from the folder must vanish
  // from the scene too.
  final http.Response deleted = await http.delete(
    Uri.parse('${env.url}/rest/v1/scene_layers?scene_id=eq.$sceneId'),
    headers: env.headers,
  );
  if (deleted.statusCode >= 300) {
    throw _UploadException(
      'Clearing old layers failed (${deleted.statusCode}): ${deleted.body}',
    );
  }

  final List<Map<String, Object?>> rows = <Map<String, Object?>>[
    for (final (SpriteFileName file, LayerManifest settings) in manifest.layers)
      <String, Object?>{
        'scene_id': sceneId,
        'z_index': file.zIndex,
        'sprite_url': spriteUrls[file.fileName],
        'frame_count': file.frameCount,
        'fps': settings.fps,
        'offset_x': settings.offsetX,
        'offset_y': settings.offsetY,
        'parallax': settings.parallax,
        'tiles': settings.tiles,
        'only_while_playing': settings.onlyWhilePlaying,
        'event_interval_min_seconds': settings.eventIntervalMinSeconds,
        'event_interval_max_seconds': settings.eventIntervalMaxSeconds,
      },
  ];

  final http.Response inserted = await http.post(
    Uri.parse('${env.url}/rest/v1/scene_layers'),
    headers: <String, String>{
      ...env.headers,
      'Content-Type': 'application/json',
    },
    body: jsonEncode(rows),
  );

  if (inserted.statusCode >= 300) {
    throw _UploadException(
      'Saving the layers failed (${inserted.statusCode}): ${inserted.body}',
    );
  }
}
