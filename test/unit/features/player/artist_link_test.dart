import 'package:flutter_test/flutter_test.dart';
import 'package:path_parsing/path_parsing.dart';
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
