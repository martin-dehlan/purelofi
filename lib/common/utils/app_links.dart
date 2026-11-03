import 'package:url_launcher/url_launcher.dart';

/// The pages on purelofi.app the app points to (#79). The stores require
/// terms and a privacy policy wherever an account or a purchase is offered.
///
/// The app holds no legal text of its own: these links are all of it.
abstract final class AppLinks {
  static final Uri terms = Uri.parse('https://purelofi.app/terms');
  static final Uri privacy = Uri.parse('https://purelofi.app/privacy');
  static final Uri imprint = Uri.parse('https://purelofi.app/imprint');

  /// The site, for sharing the app with someone.
  static final Uri home = Uri.parse('https://purelofi.app');

  /// A mail to us, with the subject filled in.
  static final Uri feedback = Uri(
    scheme: 'mailto',
    path: 'contact@purelofi.app',
    query: 'subject=PureLofi feedback',
  );

  /// A mail to us about one track, naming it so we can find it.
  static Uri report({required String trackId, required String title}) => Uri(
    scheme: 'mailto',
    path: 'contact@purelofi.app',
    query: 'subject=Problem with $title&body=Track: $trackId',
  );

  /// Opens [uri] outside the app. A link that will not open is not worth an
  /// error: the listener is still exactly where they were.
  static Future<void> open(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      // Nothing to do.
    }
  }
}
