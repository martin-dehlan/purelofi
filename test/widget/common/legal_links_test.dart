import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/common/utils/app_links.dart';
import 'package:purelofi/common/widgets/legal_links.widget.dart';

void main() {
  testWidgets('each link opens its page on purelofi.app', (tester) async {
    final List<Uri> opened = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LegalLinks(onOpen: (Uri uri) async => opened.add(uri)),
        ),
      ),
    );

    await tester.tap(find.text('Privacy'));
    await tester.tap(find.text('Terms'));
    await tester.tap(find.text('Imprint'));

    expect(opened, <Uri>[AppLinks.privacy, AppLinks.terms, AppLinks.imprint]);
    expect(opened.map((Uri uri) => uri.toString()), <String>[
      'https://purelofi.app/privacy',
      'https://purelofi.app/terms',
      'https://purelofi.app/imprint',
    ]);
  });
}
