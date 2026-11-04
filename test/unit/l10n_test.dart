import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/l10n/l10n.dart';

/// The languages stay complete and the app speaks German (#140).
void main() {
  Map<String, dynamic> arb(String locale) =>
      jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
          as Map<String, dynamic>;

  Set<String> keys(Map<String, dynamic> m) => <String>{
    for (final String k in m.keys)
      if (!k.startsWith('@')) k,
  };

  test('every language has every English key, and nothing else', () {
    final Set<String> english = keys(arb('en'));
    for (final Locale locale in AppLocalizations.supportedLocales) {
      if (locale.languageCode == 'en') continue;
      expect(
        keys(arb(locale.languageCode)),
        english,
        reason: '${locale.languageCode} must match app_en.arb',
      );
    }
  });

  test('German is offered, and reads German', () async {
    expect(
      AppLocalizations.supportedLocales.map((Locale l) => l.languageCode),
      containsAll(<String>['en', 'de']),
    );
    final AppLocalizations de = await AppLocalizations.delegate.load(
      const Locale('de'),
    );
    expect(de.play, 'Abspielen');
    expect(de.recentlyPlayed, 'Zuletzt gehört');
  });

  testWidgets('the room page holds together in German', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) =>
              Scaffold(body: Text(context.l10n.musicFollowsTheRoom)),
        ),
      ),
    );

    expect(find.text('Musik folgt dem Raum'), findsOneWidget);
  });

  test('no new hard-coded text in the interface', () {
    // Every interface string is in ARB now; keep it that way.
    const int stillInEnglish = 0;
    final RegExp literal = RegExp(
      r"""\b(?:Text\(|title:\s*|subtitle:\s*|tooltip:\s*|label:\s*|hintText:\s*)'[^']*[A-Za-z]{2}""",
    );
    int count = 0;
    for (final FileSystemEntity f in Directory(
      'lib',
    ).listSync(recursive: true)) {
      final String path = f.path.replaceAll(r'\', '/');
      if (f is! File || !path.endsWith('.dart') || path.endsWith('.g.dart')) {
        continue;
      }
      if (path.contains('/l10n/')) continue;
      if (path.contains('/presentation/') ||
          path.contains('lib/common/widgets')) {
        count += literal.allMatches(f.readAsStringSync()).length;
      }
    }

    expect(
      count,
      lessThanOrEqualTo(stillInEnglish),
      reason: 'Put new interface text in lib/l10n/app_en.arb (and app_de.arb).',
    );
  });
}
