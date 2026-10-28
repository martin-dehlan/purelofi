/// How much of the start-up bar the scene list is worth. It is one request,
/// where the sprites are several, but it is the step a dead server stalls
/// on, so it gets a visible share of its own.
const double sceneListShare = 0.15;

/// How full the start-up bar is, from 0 to 1, once the scene list is in and
/// [spritesLoaded] of [spritesTotal] strips have landed.
///
/// Every strip counts the same: they are fetched in parallel, so the count
/// is the only honest measure there is — Flutter's image pipeline reports no
/// bytes for a strip until it is whole.
double startupFraction({
  required int spritesLoaded,
  required int spritesTotal,
}) {
  if (spritesTotal <= 0) return 1;

  final double sprites = spritesLoaded.clamp(0, spritesTotal) / spritesTotal;

  return sceneListShare + (1 - sceneListShare) * sprites;
}
