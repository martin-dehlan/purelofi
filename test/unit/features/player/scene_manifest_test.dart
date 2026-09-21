import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/features/player/data/scene_manifest.dart';

void main() {
  const String validJson = '''
{
  "title": "Rainy Room",
  "canvas": { "width": 320, "height": 696 },
  "layers": {
    "L00_room": { "parallax": 0.5 },
    "L03_rain": { "fps": 12, "tiles": true, "offset": [10, 20] }
  }
}
''';

  group('SpriteFileName', () {
    test('reads depth, name and frame count from the file name', () {
      final SpriteFileName file = SpriteFileName.parse('L03_rain_near_6f.png');

      expect(file.zIndex, 3);
      expect(file.name, 'rain_near');
      expect(file.frameCount, 6);
      expect(file.manifestKey, 'L03_rain_near');
    });

    test('rejects a name that does not follow the convention', () {
      expect(
        () => SpriteFileName.parse('rain.png'),
        throwsA(
          isA<SceneManifestException>().having(
            (SceneManifestException e) => e.message,
            'message',
            allOf(contains('rain.png'), contains('L03_rain_6f.png')),
          ),
        ),
      );
    });

    test('rejects a missing frame suffix', () {
      expect(
        () => SpriteFileName.parse('L03_rain.png'),
        throwsA(isA<SceneManifestException>()),
      );
    });
  });

  group('SceneManifest', () {
    test('pairs each sprite with its settings, back to front', () {
      final SceneManifest manifest = SceneManifest.parse(
        sceneJson: validJson,
        spriteFileNames: <String>['L03_rain_6f.png', 'L00_room_1f.png'],
      );

      expect(manifest.title, 'Rainy Room');
      expect(manifest.canvasWidth, 320);
      expect(manifest.canvasHeight, 696);
      expect(
        manifest.layers.map(((SpriteFileName, LayerManifest) l) => l.$1.name),
        <String>['room', 'rain'],
      );
      expect(manifest.layers.first.$2.parallax, 0.5);
      expect(manifest.layers.last.$2.fps, 12);
      expect(manifest.layers.last.$2.tiles, isTrue);
      expect(manifest.layers.last.$2.offsetX, 10);
      expect(manifest.layers.last.$2.offsetY, 20);
    });

    test('names the file when a sprite has no entry', () {
      expect(
        () => SceneManifest.parse(
          sceneJson: validJson,
          spriteFileNames: <String>[
            'L00_room_1f.png',
            'L03_rain_6f.png',
            'L07_cat_4f.png',
          ],
        ),
        throwsA(
          isA<SceneManifestException>().having(
            (SceneManifestException e) => e.message,
            'message',
            allOf(contains('L07_cat_4f.png'), contains('L07_cat')),
          ),
        ),
      );
    });

    test('catches an entry with no sprite', () {
      expect(
        () => SceneManifest.parse(
          sceneJson: validJson,
          spriteFileNames: <String>['L00_room_1f.png'],
        ),
        throwsA(
          isA<SceneManifestException>().having(
            (SceneManifestException e) => e.message,
            'message',
            contains('L03_rain'),
          ),
        ),
      );
    });

    test('rejects an animation without an fps', () {
      const String json = '''
{ "layers": { "L01_steam": { "parallax": 1 } } }
''';

      expect(
        () => SceneManifest.parse(
          sceneJson: json,
          spriteFileNames: <String>['L01_steam_7f.png'],
        ),
        throwsA(
          isA<SceneManifestException>().having(
            (SceneManifestException e) => e.message,
            'message',
            contains('no fps'),
          ),
        ),
      );
    });

    test('rejects a still frame that claims an fps', () {
      const String json = '''
{ "layers": { "L01_wall": { "fps": 12 } } }
''';

      expect(
        () => SceneManifest.parse(
          sceneJson: json,
          spriteFileNames: <String>['L01_wall_1f.png'],
        ),
        throwsA(
          isA<SceneManifestException>().having(
            (SceneManifestException e) => e.message,
            'message',
            contains('single frame'),
          ),
        ),
      );
    });

    test('rejects two layers at the same depth', () {
      const String json = '''
{ "layers": { "L02_a": {}, "L02_b": {} } }
''';

      expect(
        () => SceneManifest.parse(
          sceneJson: json,
          spriteFileNames: <String>['L02_a_1f.png', 'L02_b_1f.png'],
        ),
        throwsA(
          isA<SceneManifestException>().having(
            (SceneManifestException e) => e.message,
            'message',
            contains('z_index 2'),
          ),
        ),
      );
    });

    test('reads a rare event interval', () {
      const String json = '''
{ "layers": { "L05_car": { "fps": 12, "event_interval": [40, 90] } } }
''';

      final SceneManifest manifest = SceneManifest.parse(
        sceneJson: json,
        spriteFileNames: <String>['L05_car_24f.png'],
      );

      expect(manifest.layers.single.$2.eventIntervalMinSeconds, 40);
      expect(manifest.layers.single.$2.eventIntervalMaxSeconds, 90);
    });

    test('rejects a half-specified event interval', () {
      const String json = '''
{ "layers": { "L05_car": { "fps": 12, "event_interval": [40] } } }
''';

      expect(
        () => SceneManifest.parse(
          sceneJson: json,
          spriteFileNames: <String>['L05_car_24f.png'],
        ),
        throwsA(isA<SceneManifestException>()),
      );
    });

    test('falls back to the standard canvas when none is given', () {
      const String json = '{ "layers": { "L00_a": {} } }';

      final SceneManifest manifest = SceneManifest.parse(
        sceneJson: json,
        spriteFileNames: <String>['L00_a_1f.png'],
      );

      expect(manifest.canvasWidth, 320);
      expect(manifest.canvasHeight, 696);
    });
  });

  group('hide_when_paused', () {
    test('is read from scene.json', () {
      const String json = '''
{ "layers": { "L11_lamp": { "hide_when_paused": true } } }
''';

      final SceneManifest manifest = SceneManifest.parse(
        sceneJson: json,
        spriteFileNames: <String>['L11_lamp_1f.png'],
      );

      expect(manifest.layers.single.$2.hideWhenPaused, isTrue);
    });

    test('defaults to false', () {
      final SceneManifest manifest = SceneManifest.parse(
        sceneJson: '{ "layers": { "L00_a": {} } }',
        spriteFileNames: <String>['L00_a_1f.png'],
      );

      expect(manifest.layers.single.$2.hideWhenPaused, isFalse);
    });
  });
}
