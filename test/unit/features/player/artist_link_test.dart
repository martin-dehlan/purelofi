import 'package:flutter_test/flutter_test.dart';
import 'package:path_parsing/path_parsing.dart';
import 'package:purelofi/features/player/data/artist.model.dart';
import 'package:purelofi/features/player/domain/artist_link.dart';
import 'package:purelofi/features/player/presentation/widgets/artist_link_marks.dart';

void main() {
  test('names the place a link points at', () {
    expect(artistLinkLabel('https://www.youtube.com/@Massomusic'), 'YouTube');
    expect(artistLinkLabel('https://soundcloud.com/massomusic'), 'SoundCloud');
    expect(artistLinkLabel('https://open.spotify.com/artist/x'), 'Spotify');
    expect(
      artistLinkLabel('https://music.apple.com/de/artist/x'),
      'Apple Music',
    );
    expect(artistLinkLabel('https://x.com/someone'), 'X');
  });

  test('anything else is their own site', () {
    expect(artistLinkLabel('https://massomusic.com'), 'Website');
    // Not fooled by a host that only ends in the same letters.
    expect(artistLinkLabel('https://notyoutube.com/x'), 'Website');
    expect(artistLinkLabel('not a url'), 'Website');
  });

  test('every mark is a path that parses', () {
    for (final MapEntry<String, String> mark in artistLinkMarks.entries) {
      expect(
        () => writeSvgPathDataToPath(mark.value, _Counting()),
        returnsNormally,
        reason: mark.key,
      );
    }
  });

  test('only web links leave the app', () {
    expect(isWebLink('https://soundcloud.com/massomusic'), isTrue);
    expect(isWebLink('http://massomusic.com'), isTrue);
    expect(isWebLink('javascript:alert(1)'), isFalse);
    expect(isWebLink('intent://scan/#Intent;scheme=zxing;end'), isFalse);
    expect(isWebLink('file:///data/data/app.purelofi/shared_prefs'), isFalse);
    expect(isWebLink('tel:+491234'), isFalse);
    expect(isWebLink('https:///no-host'), isFalse);
    expect(isWebLink('not a url'), isFalse);
  });

  test('an artist row keeps its web links and drops the rest', () {
    const ArtistModel model = ArtistModel(
      id: 'a',
      name: 'Masso',
      links: <String>[
        'https://www.youtube.com/@Massomusic',
        'intent://evil#Intent;end',
        'javascript:alert(1)',
      ],
    );

    expect(model.toEntity().links, <String>[
      'https://www.youtube.com/@Massomusic',
    ]);
  });

  test('a legacy link_url is filtered the same way', () {
    const ArtistModel model = ArtistModel(
      id: 'a',
      name: 'Masso',
      linkUrl: 'file:///etc/hosts',
    );

    expect(model.toEntity().links, isEmpty);
  });
}

class _Counting extends PathProxy {
  @override
  void close() {}

  @override
  void cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x3,
    double y3,
  ) {}

  @override
  void lineTo(double x, double y) {}

  @override
  void moveTo(double x, double y) {}
}
