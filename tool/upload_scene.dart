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

/// A sprite strip costs width x height x 4 bytes once Flutter decodes it, and
/// every layer of a scene is decoded at once. Flutter's image cache holds
/// 100 MB; past that it silently drops the biggest entries and those layers
/// simply never appear. These limits leave room for the rest of the app.
const double _sceneBudgetMegabytes = 48;
const double _layerBudgetMegabytes = 4;

/// How much of the canvas a phone can cut off, as a fraction of each side.
///
/// A scene is scaled by whole device pixels to stay crisp, which means the
/// scale is rounded up and the overflow falls off the edges. How much
/// overflows depends on the screen, and not in the way the aspect ratio
/// suggests: an iPhone SE is 9:16 like the canvas, needs 2.35x, gets 3x, and
/// loses 62 of 568 rows top and bottom — more than any taller phone. The
/// widest side crop is a Pixel's 52 of 320 columns.
///
/// Measured across real phones, from the SE to a 21:9 Xperia:
///
///   iPhone SE 3        x  35..285   y  62..506
///   iPhone 13 mini     x  48..272   y  40..528
///   iPhone 17          x  39..281   y  22..546
///   iPhone 16 Pro Max  x  50..270   y  45..523
///   Pixel 9a           x  52..268   y  42..526
///   Galaxy S24 Ultra   x  40..280   y  24..544
///   Xperia 1 V         x  43..277   y  10..558
///
/// Anything that must be seen belongs inside what survives all of them;
/// anything the listener can touch has to be.
const double _safeInsetX = 0.165;
const double _safeInsetY = 0.11;

/// Refuses a scene that would not fit in the image cache.
///
/// Almost always the fix is the same: crop the strip to the pixels it
/// actually uses and put it back in place with an offset. A full-canvas strip
/// for a four-pixel LED costs 22 MB; cropped it costs 32 KB.
void _checkMemoryBudget(double totalMegabytes, List<String> oversized) {
  stdout.writeln(
    '\nDecoded size ${totalMegabytes.toStringAsFixed(1)} MB '
    'of ${_sceneBudgetMegabytes.toStringAsFixed(0)} MB budget',
  );

  if (oversized.isNotEmpty) {
    stdout.writeln(
      'Layers above ${_layerBudgetMegabytes.toStringAsFixed(0)} MB — crop '
      'these to their bounding box and give them an offset:',
    );
    oversized.forEach(stdout.writeln);
  }

  if (totalMegabytes > _sceneBudgetMegabytes) {
    throw _UploadException(
      'This scene needs ${totalMegabytes.toStringAsFixed(1)} MB of image '
      'cache, over the ${_sceneBudgetMegabytes.toStringAsFixed(0)} MB budget. '
      'Flutter would drop the biggest strips and those layers would not be '
      'drawn at all. Crop the strips listed above.',
    );
  }
}

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

/// Reports what a phone will cut off, and refuses a scene whose listener
/// could be asked to touch something that is not on screen.
void _checkSafeArea(
  SceneManifest manifest,
  Map<String, (int, int, int, int)> boxes,
) {
  final int left = (manifest.canvasWidth * _safeInsetX).round();
  final int top = (manifest.canvasHeight * _safeInsetY).round();
  final int right = manifest.canvasWidth - left;
  final int bottom = manifest.canvasHeight - top;

  stdout.writeln('\nSafe area x $left..$right, y $top..$bottom');

  final List<String> clipped = <String>[];
  final List<String> unreachable = <String>[];

  for (final (SpriteFileName file, LayerManifest settings) in manifest.layers) {
    final (int x0, int y0, int x1, int y1) = boxes[file.name]!;
    if (x0 >= left && y0 >= top && x1 <= right && y1 <= bottom) continue;

    final String where = '  ${file.name.padRight(16)} x $x0..$x1, y $y0..$y1';
    // A background is meant to bleed past the edges; that is what the
    // overflow is for. Something the listener taps is a different matter —
    // unless it takes itself off screen rather than be shown half cropped,
    // which is what hide_when_clipped is for.
    final bool isProblem = settings.tappable && !settings.hideWhenClipped;
    (isProblem ? unreachable : clipped).add(where);
  }

  if (clipped.isNotEmpty) {
    stdout.writeln('Reaches past it (fine for backgrounds):');
    clipped.forEach(stdout.writeln);
  }

  if (unreachable.isNotEmpty) {
    throw _UploadException(
      'A tappable layer reaches outside the safe area, so on some phones it '
      'is half off screen or gone entirely and the tap has nothing to hit:\n'
      '${unreachable.join('\n')}',
    );
  }
}

Future<void> _run(_Args args) async {
  if (!args.dir.existsSync()) {
    throw _UploadException('No such folder: ${args.dir.path}');
  }

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

  final List<String> oversized = <String>[];
  final Map<String, (int, int, int, int)> boxes =
      <String, (int, int, int, int)>{};
  double totalMegabytes = 0;

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
    boxes[file.name] = (
      settings.offsetX,
      settings.offsetY,
      settings.offsetX + frameWidth,
      settings.offsetY + height,
    );
    final double megabytes = width * height * 4 / (1024 * 1024);
    totalMegabytes += megabytes;
    if (megabytes > _layerBudgetMegabytes) {
      oversized.add(
        '  ${file.fileName}  ${megabytes.toStringAsFixed(1)} MB '
        '(${frameWidth}x$height x${file.frameCount})',
      );
    }

    stdout.writeln(
      '  ${file.zIndex.toString().padLeft(2, '0')}  ${file.name.padRight(16)} '
      '${frameWidth}x$height x${file.frameCount}'
      '${settings.fps > 0 ? ' @${settings.fps}fps' : ''}'
      '${settings.tiles ? ' tiling' : ''}'
      '${settings.onlyWhilePlaying ? ' while-playing' : ''}'
      '${settings.hideWhenPaused ? ' hidden-when-paused' : ''}'
      '${settings.tappable ? ' tappable' : ''}'
      '${settings.idleFrameCount > 0 ? ' idle:${settings.idleFrameCount}' : ''}'
      '${settings.onTrackChange ? ' on-track-change' : ''}'
      '${settings.hideWhenClipped ? ' hide-when-clipped' : ''}',
    );
  }

  _checkMemoryBudget(totalMegabytes, oversized);
  _checkSafeArea(manifest, boxes);

  if (args.dryRun) {
    stdout.writeln('\n--dry-run: nothing uploaded.');
    return;
  }

  // Loaded here rather than at the top: a dry run validates the folder and
  // has no business asking for credentials.
  final _Env env = _Env.load();

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

  // 4. The cover, if one was built. Not a layer — nothing draws it; it is
  //    what the lock screen shows instead of a black rectangle.
  String? coverUrl;
  final File cover = File('${args.dir.path}/${SceneManifest.coverFileName}');
  if (cover.existsSync()) {
    final String path = '${args.scene}/${SceneManifest.coverFileName}';
    await _uploadSprite(env, path, cover);
    coverUrl = '${env.url}/storage/v1/object/public/$_bucket/$path';
    stdout.writeln('  ${SceneManifest.coverFileName}');
  } else {
    stdout.writeln(
      '\nNo ${SceneManifest.coverFileName}: the lock screen will be blank. '
      'Build one with tool/scene_cover.py.',
    );
  }

  // 5. Upsert the scene, then replace its layers.
  final String sceneId = await _upsertScene(
    env,
    args.scene,
    manifest,
    coverUrl,
  );
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

  /// Reads the env files directly — this runs outside Flutter, so dotenv is
  /// not available.
  ///
  /// Two files, on purpose. `.env` is bundled into the app by
  /// `pubspec.yaml`, so it holds only what is safe in a stranger's hands.
  /// The service role key bypasses row-level security, so it lives in
  /// `.env.tools`, which nothing but this folder reads.
  static _Env load() {
    final Map<String, String> app = _read(File('.env'));
    if (app.isEmpty) {
      throw const _UploadException(
        'No .env in the current folder. Run this from the repo root.',
      );
    }

    final Map<String, String> tools = _read(File('.env.tools'));

    final String url = app['SUPABASE_URL'] ?? '';
    final String key =
        tools['SUPABASE_SERVICE_ROLE_KEY'] ??
        Platform.environment['SUPABASE_SERVICE_ROLE_KEY'] ??
        '';

    if (url.isEmpty) throw const _UploadException('SUPABASE_URL is not set');
    if (key.isEmpty) {
      throw const _UploadException(
        'SUPABASE_SERVICE_ROLE_KEY is not set. Uploading needs it and the '
        'anon key is read-only, but it must not go in .env — that file is '
        'bundled into the app. Copy .env.tools.example to .env.tools and put '
        'it there.',
      );
    }

    return _Env(url: url, serviceRoleKey: key);
  }

  /// A `KEY=value` file as a map; an absent file is an empty one.
  static Map<String, String> _read(File file) {
    if (!file.existsSync()) return <String, String>{};

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

    return values;
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
      // A replaced sprite keeps its URL, so without this the CDN would keep
      // serving the old one for an hour and nobody would see the change.
      'cache-control': 'max-age=60',
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
  String? coverUrl,
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
      'thumbnail_url': ?coverUrl,
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
        'hide_when_paused': settings.hideWhenPaused,
        'tappable': settings.tappable,
        'idle_frame_count': settings.idleFrameCount,
        'on_track_change': settings.onTrackChange,
        'hide_when_clipped': settings.hideWhenClipped,
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
