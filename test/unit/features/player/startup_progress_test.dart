import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/features/player/domain/startup_progress.dart';

void main() {
  test('starts at the scene list share once the list is in', () {
    expect(startupFraction(spritesLoaded: 0, spritesTotal: 4), sceneListShare);
  });

  test('fills evenly with each strip', () {
    final double half = startupFraction(spritesLoaded: 2, spritesTotal: 4);

    expect(half, closeTo(sceneListShare + (1 - sceneListShare) / 2, 1e-9));
  });

  test('is full when every strip has landed', () {
    expect(startupFraction(spritesLoaded: 4, spritesTotal: 4), 1);
  });

  test('never runs past full', () {
    expect(startupFraction(spritesLoaded: 9, spritesTotal: 4), 1);
  });

  test('a room with nothing to fetch is already full', () {
    expect(startupFraction(spritesLoaded: 0, spritesTotal: 0), 1);
  });
}
