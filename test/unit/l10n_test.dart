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

  test('every placeholder survives in every language', () {
    final Map<String, dynamic> english = arb('en');
    final RegExp placeholder = RegExp(r'\{(\w+)[,}]');
    Set<String> names(String s) =>
        placeholder.allMatches(s).map((Match m) => m.group(1)!).toSet();
    for (final Locale locale in AppLocalizations.supportedLocales) {
      final Map<String, dynamic> other = arb(locale.languageCode);
      for (final String key in keys(english)) {
        expect(
          names(other[key] as String),
          names(english[key] as String),
          reason: '${locale.languageCode}: $key',
        );
      }
    }
  });

  test('the languages for lo-fi listeners are offered, each in its own '
      'words (#174)', () async {
    const Map<String, String> play = <String, String>{
      'es': 'Reproducir',
      'pt': 'Tocar',
      'fr': 'Lecture',
      'it': 'Riproduci',
      'nl': 'Afspelen',
      'pl': 'Odtwórz',
      'tr': 'Çal',
      'ru': 'Играть',
      'ja': '再生',
      'ko': '재생',
      'zh': '播放',
      'id': 'Putar',
    };
    expect(
      AppLocalizations.supportedLocales.map((Locale l) => l.languageCode),
      containsAll(play.keys),
    );
    for (final MapEntry<String, String> e in play.entries) {
      final AppLocalizations l10n = await AppLocalizations.delegate.load(
        Locale(e.key),
      );
      expect(l10n.play, e.value, reason: e.key);
      // The name and the plan keep their own names everywhere.
      expect(l10n.purelofiPro, 'PureLofi Pro', reason: e.key);
    }
  });

  test('counts read right where a language has more than one plural', () async {
    final AppLocalizations ru = await AppLocalizations.delegate.load(
      const Locale('ru'),
    );
    expect(ru.trackCount(1), '1 трек');
    expect(ru.trackCount(3), '3 трека');
    expect(ru.trackCount(5), '5 треков');
    expect(ru.trackCount(21), '21 трек');
    final AppLocalizations pl = await AppLocalizations.delegate.load(
      const Locale('pl'),
    );
    expect(pl.trackCount(2), '2 utwory');
    expect(pl.trackCount(5), '5 utworów');
    final AppLocalizations ja = await AppLocalizations.delegate.load(
      const Locale('ja'),
    );
    expect(ja.trackCount(1), '1 曲');
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
      reason:
          'Put new interface text in lib/l10n/app_en.arb and every other app_*.arb.',
    );
  });
}
