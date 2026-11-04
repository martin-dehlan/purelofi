/// What an artist link points at, read from its host, so the artist page
/// can say "YouTube" instead of a URL.
///
/// Unknown hosts are the artist's own site: "Website".
String artistLinkLabel(String url) {
  final String host = (Uri.tryParse(url)?.host ?? '').toLowerCase();
  bool on(String domain) => host == domain || host.endsWith('.$domain');

  if (on('youtube.com') || on('youtu.be')) return 'YouTube';
  if (on('soundcloud.com')) return 'SoundCloud';
  if (on('spotify.com')) return 'Spotify';
  if (on('music.apple.com')) return 'Apple Music';
  if (on('instagram.com')) return 'Instagram';
  if (on('tiktok.com')) return 'TikTok';
  if (on('bandcamp.com')) return 'Bandcamp';
  if (on('x.com') || on('twitter.com')) return 'X';
  if (on('facebook.com')) return 'Facebook';
  if (on('twitch.tv')) return 'Twitch';
  if (on('deezer.com')) return 'Deezer';
  if (on('tidal.com')) return 'Tidal';
  if (on('patreon.com')) return 'Patreon';
  if (on('linktr.ee')) return 'Linktree';

  return 'Website';
}

/// Whether [url] is a web link the app may open outside itself.
///
/// Artist links come from the database and leave the app through the
/// platform's URL handler, which also takes `intent:`, `file:`, `tel:` and
/// whatever scheme another installed app has claimed. Only http(s) links
/// with a host are artist channels; anything else is dropped, however it got
/// into the row.
bool isWebLink(String url) {
  final Uri? uri = Uri.tryParse(url.trim());
  if (uri == null || uri.host.isEmpty) return false;

  return uri.scheme == 'https' || uri.scheme == 'http';
}

/// Where a support link goes, so the button can say so: "Bandcamp",
/// "Ko-fi". `null` for anything else: the artist's own page, which the
/// interface names in the listener's language (#152, #140).
String? supportPlatform(String url) {
  final String host = (Uri.tryParse(url)?.host ?? '').toLowerCase();
  bool on(String domain) => host == domain || host.endsWith('.$domain');

  if (on('bandcamp.com')) return 'Bandcamp';
  if (on('ko-fi.com')) return 'Ko-fi';
  if (on('patreon.com')) return 'Patreon';
  if (on('buymeacoffee.com')) return 'Buy Me a Coffee';
  if (on('paypal.me') || on('paypal.com')) return 'PayPal';

  return null;
}
