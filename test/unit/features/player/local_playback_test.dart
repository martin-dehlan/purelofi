import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:purelofi/features/player/data/audio_player.service.impl.dart';
import 'package:purelofi/features/player/domain/track.entity.dart';

import '../../../helpers/fake_media_cache.dart';

class _MockPlayer extends Mock implements AudioPlayer {}

class _FakeSource extends Fake implements AudioSource {}

void main() {
  late _MockPlayer player;
  late FakeMediaCache cache;
  late AudioPlayerServiceImpl service;
  AudioSource? loaded;

  setUpAll(() => registerFallbackValue(_FakeSource()));

  setUp(() {
    player = _MockPlayer();
    cache = FakeMediaCache();
    loaded = null;
    when(
      () => player.playbackEventStream,
    ).thenAnswer((_) => const Stream<PlaybackEvent>.empty());
    when(
      () => player.processingStateStream,
    ).thenAnswer((_) => const Stream<ProcessingState>.empty());
    when(() => player.setAudioSource(any())).thenAnswer((Invocation i) async {
      loaded = i.positionalArguments.first as AudioSource;
      return null;
    });
    when(player.play).thenAnswer((_) async {});
    service = AudioPlayerServiceImpl(player: player, cache: cache);
  });

  TrackEntity local({String? artist}) => TrackEntity(
    id: 'mine',
    title: 'Kitchen Demo',
    artist: artist,
    audioUrl: Uri.file('/data/library/mine.mp3').toString(),
    createdAt: DateTime.utc(2026, 9, 28),
    source: TrackSource.local,
  );

  test(
    'a local track plays from its file and never touches the cache',
    () async {
      await service.playTrack(local());

      expect(loaded, isA<UriAudioSource>());
      expect(
        (loaded! as UriAudioSource).uri,
        Uri.file('/data/library/mine.mp3'),
      );
      expect(
        cache.stored,
        isEmpty,
        reason: 'the cache evicts; this is the only copy',
      );
    },
  );

  test('the lock screen shows its own artist, not PureLofi', () async {
    await service.playTrack(local(artist: 'A Friend'));
    expect(service.mediaItem.value?.artist, 'A Friend');

    await service.playTrack(local());
    expect(service.mediaItem.value?.artist, isNull);
  });

  test('the catalogue still signs as PureLofi and still caches', () async {
    await service.playTrack(
      TrackEntity(
        id: 'a',
        title: 'Travel Lofi',
        audioUrl: 'https://example.com/a.mp3',
        createdAt: DateTime.utc(2026, 9, 28),
      ),
    );

    final MediaItem? item = service.mediaItem.value;
    expect(item?.artist, 'PureLofi');
    expect(cache.stored, <String>['https://example.com/a.mp3']);
  });

  group('a scene switch mid-track', () {
    // The lock screen names the room the listener is in, and follows it.
    test('names the room as the album, with the new cover', () async {
      await service.setArtwork(
        Uri.file('/cache/autumn.png'),
        room: 'Autumn Bookshop',
      );
      await service.playTrack(local());
      expect(service.mediaItem.value?.album, 'Autumn Bookshop');

      await service.setArtwork(Uri.file('/cache/snow.png'), room: 'Snow Cabin');

      final MediaItem? item = service.mediaItem.value;
      expect(item?.title, 'Kitchen Demo');
      expect(item?.album, 'Snow Cabin');
      expect(item?.artUri, Uri.file('/cache/snow.png'));
    });

    test('a new track keeps the room it is in', () async {
      await service.setArtwork(Uri.file('/cache/snow.png'), room: 'Snow Cabin');
      await service.playTrack(local());

      expect(service.mediaItem.value?.album, 'Snow Cabin');
    });
  });

  group('on Android', () {
    // MIUI draws a title's cover once and never again (#77): the same track
    // in another room has to be another title there.
    late AudioPlayerServiceImpl android;

    setUp(() {
      android = AudioPlayerServiceImpl(
        player: player,
        cache: cache,
        roomInTitle: true,
      );
    });

    test('the room rides along in the title', () async {
      await android.setArtwork(
        Uri.file('/cache/autumn.png'),
        room: 'Autumn Bookshop',
      );
      await android.playTrack(local());
      expect(android.mediaItem.value?.title, 'Kitchen Demo · Autumn Bookshop');

      await android.setArtwork(Uri.file('/cache/snow.png'), room: 'Snow Cabin');
      expect(android.mediaItem.value?.title, 'Kitchen Demo · Snow Cabin');
    });

    test('switching back is the first title again, not a pile-up', () async {
      await android.setArtwork(
        Uri.file('/cache/a.png'),
        room: 'Autumn Bookshop',
      );
      await android.playTrack(local());
      await android.setArtwork(Uri.file('/cache/b.png'), room: 'Snow Cabin');
      await android.setArtwork(
        Uri.file('/cache/a.png'),
        room: 'Autumn Bookshop',
      );

      expect(android.mediaItem.value?.title, 'Kitchen Demo · Autumn Bookshop');
    });

    test('with no room yet, the title is the track alone', () async {
      await android.playTrack(local());

      expect(android.mediaItem.value?.title, 'Kitchen Demo');
    });
  });
}
