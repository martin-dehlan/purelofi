import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/common/utils/app_links.dart';

void main() {
  group('AppLinks.isAllowed', () {
    test('lets web links and mail through', () {
      expect(AppLinks.isAllowed(AppLinks.terms), isTrue);
      expect(AppLinks.isAllowed(AppLinks.feedback), isTrue);
      expect(
        AppLinks.isAllowed(
          Uri.parse('https://apps.apple.com/account/subscriptions'),
        ),
        isTrue,
      );
    });

    test('keeps every other scheme in the app', () {
      for (final String url in <String>[
        'javascript:alert(1)',
        'intent://scan/#Intent;scheme=zxing;end',
        'file:///data/data/app.purelofi/shared_prefs/x.xml',
        'tel:+491234',
        'sms:+491234',
        'purelofi://app/auth-callback',
        'https:///no-host',
      ]) {
        expect(AppLinks.isAllowed(Uri.parse(url)), isFalse, reason: url);
      }
    });
  });

  group('AppLinks.report', () {
    test('a title cannot add recipients to the mail', () {
      final Uri uri = AppLinks.report(
        trackId: 't1',
        title: 'Rain & cc=someone@example.com&bcc=x@example.com',
      );

      expect(
        uri.queryParameters.keys,
        unorderedEquals(<String>['subject', 'body']),
      );
      expect(
        uri.queryParameters['subject'],
        'Problem with Rain & cc=someone@example.com&bcc=x@example.com',
      );
      expect(uri.queryParameters['body'], 'Track: t1');
    });
  });
}
