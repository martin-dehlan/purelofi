import 'dart:math';

import 'track.entity.dart';

/// How far ahead the stream is planned: enough to fill a screen of "next
/// from", few enough that a change of mind costs nothing to redo.
const int upNextLength = 10;

/// How much likelier a favourite is than anything else.
const int favoriteWeight = 3;

/// One of [tracks], with the ones in [favorites] counted [favoriteWeight]
/// times over.
///
/// Pure and injectable so the weighting can be tested without waiting for a
/// few hundred tracks to play.
TrackEntity pickWeighted(
  List<TrackEntity> tracks, {
  required Set<String> favorites,
  required Random random,
}) {
  int total = 0;
  for (final TrackEntity track in tracks) {
    total += favorites.contains(track.id) ? favoriteWeight : 1;
  }

  int roll = random.nextInt(total);
  for (final TrackEntity track in tracks) {
    roll -= favorites.contains(track.id) ? favoriteWeight : 1;
    if (roll < 0) return track;
  }

  return tracks.last;
}

/// The [count] tracks after [currentId] in [ordered], round the end. With
/// nothing playing, or a current track not in the list, it starts at the
/// top. Never the current track itself, unless it is the only one.
List<TrackEntity> upNextInOrder(
  List<TrackEntity> ordered, {
  required String? currentId,
  int count = upNextLength,
}) {
  if (ordered.isEmpty) return const <TrackEntity>[];

  final int at = ordered.indexWhere((TrackEntity t) => t.id == currentId);
  if (at < 0) return ordered.take(count).toList();
  if (ordered.length == 1) return <TrackEntity>[ordered.single];

  return <TrackEntity>[
    for (int i = 1; i <= min(count, ordered.length - 1); i++)
      ordered[(at + i) % ordered.length],
  ];
}

/// [planned] topped up with random picks from [tracks], none of them twice.
///
/// Each pick is any track but the one before it — the current track for the
/// first — so the stream never plays the same thing twice running, and the
/// plan never lists a title twice. That needs room to choose: the plan stays
/// two shorter than the catalogue, or every pick would be forced and the
/// "shuffle" a fixed loop. A catalogue of one or two plans a single track —
/// with one, that is the same track again, because that is what plays next.
///
/// Planned tracks that have gone from [tracks] are dropped first. Picks are
/// weighted, so favourites still come up more often.
List<TrackEntity> upNextShuffled(
  List<TrackEntity> tracks, {
  required String? currentId,
  required Set<String> favorites,
  required Random random,
  List<TrackEntity> planned = const <TrackEntity>[],
  int count = upNextLength,
}) {
  if (tracks.isEmpty) return const <TrackEntity>[];

  final Set<String> known = <String>{for (final TrackEntity t in tracks) t.id};
  final List<TrackEntity> next = <TrackEntity>[];
  for (final TrackEntity t in planned) {
    if (known.contains(t.id) && !next.any((TrackEntity n) => n.id == t.id)) {
      next.add(t);
    }
  }

  final int length = tracks.length <= 2 ? 1 : min(count, tracks.length - 2);
  while (next.length < length) {
    final String? before = next.isEmpty ? currentId : next.last.id;
    final Set<String> listed = <String>{for (final TrackEntity t in next) t.id};
    List<TrackEntity> candidates = tracks
        .where((TrackEntity t) => t.id != before && !listed.contains(t.id))
        .toList();
    if (candidates.isEmpty) {
      candidates = tracks.where((TrackEntity t) => t.id != before).toList();
    }
    if (candidates.isEmpty) candidates = tracks;

    next.add(pickWeighted(candidates, favorites: favorites, random: random));
  }

  return next;
}
