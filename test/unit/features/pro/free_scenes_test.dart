import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/features/player/domain/scene.entity.dart';
import 'package:purelofi/features/pro/domain/free_scenes.dart';

import '../../../helpers/mock_repositories.dart';

void main() {
  SceneEntity scene(String id, int order) =>
      makeScene(id).copyWith(sortOrder: order);

  final List<SceneEntity> scenes = <SceneEntity>[
    scene('night-train', 4),
    scene('autumn', 1),
    scene('rainy', 2),
    scene('snow', 3),
  ];

  test('the first two by sort_order are free, whatever the list order', () {
    expect(freeSceneIds(scenes), <String>{'autumn', 'rainy'});
  });

  test('without Pro, the rest are locked', () {
    expect(lockedSceneIds(scenes, isPro: false, proAvailable: true), <String>{
      'snow',
      'night-train',
    });
  });

  test('with Pro, nothing is locked', () {
    expect(lockedSceneIds(scenes, isPro: true, proAvailable: true), isEmpty);
  });

  test('where Pro cannot be bought, nothing is locked either', () {
    expect(lockedSceneIds(scenes, isPro: false, proAvailable: false), isEmpty);
  });

  test('two scenes or fewer: all free', () {
    expect(
      lockedSceneIds(
        <SceneEntity>[scene('a', 1), scene('b', 2)],
        isPro: false,
        proAvailable: true,
      ),
      isEmpty,
    );
  });

  test('a tie on sort_order is broken the same way every time', () {
    final List<SceneEntity> tied = <SceneEntity>[
      scene('c', 1),
      scene('a', 1),
      scene('b', 1),
    ];

    expect(freeSceneIds(tied), <String>{'a', 'b'});
  });
}
