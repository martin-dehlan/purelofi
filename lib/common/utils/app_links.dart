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
  ///
  /// The title comes from the database, so it is encoded: an `&` or `=` in
  /// it must stay part of the subject, not start a `cc=` or `bcc=` of its
  /// own.
  static Uri report({required String trackId, required String title}) => Uri(
    scheme: 'mailto',
    path: 'contact@purelofi.app',
    query:
        'subject=${Uri.encodeComponent('Problem with $title')}'
        '&body=${Uri.encodeComponent('Track: $trackId')}',
  );

  /// The schemes the app hands to the platform. Anything else — `intent:`,
  /// `file:`, `tel:`, another app's custom scheme — stays in the app, even if
  /// a row in the database or a store's answer asks for it.
  static const Set<String> allowedSchemes = <String>{'https', 'http', 'mailto'};

  /// Whether [uri] is a link [open] will hand on.
  static bool isAllowed(Uri uri) =>
      allowedSchemes.contains(uri.scheme.toLowerCase()) &&
      (uri.scheme.toLowerCase() == 'mailto' || uri.host.isNotEmpty);

  /// [open] for a link that arrived as text — from the database or a store.
  /// One that does not parse is ignored like one that will not open.
  static Future<void> openUrl(String url) async {
    final Uri? uri = Uri.tryParse(url.trim());
    if (uri != null) await open(uri);
  }

  /// Opens [uri] outside the app. A link that will not open is not worth an
  /// error: the listener is still exactly where they were.
  static Future<void> open(Uri uri) async {
    if (!isAllowed(uri)) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      // Nothing to do.
    }
  }
}
