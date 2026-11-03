import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/features/player/domain/artist_link.dart';

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
}
