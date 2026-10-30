import 'package:url_launcher/url_launcher.dart';

/// The pages on purelofi.app the app points to (#79). The stores require
/// terms and a privacy policy wherever an account or a purchase is offered.
abstract final class AppLinks {
  static final Uri terms = Uri.parse('https://purelofi.app/terms');
  static final Uri privacy = Uri.parse('https://purelofi.app/privacy');

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
