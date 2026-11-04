import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/l10n/l10n.dart';
import 'package:purelofi/common/widgets/loading_dots.widget.dart';

void main() {
  Future<void> pumpDots(WidgetTester tester, {bool still = false}) =>
      tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(400, 800),
            ).copyWith(disableAnimations: still),
            child: const Center(
              child: LoadingDots(size: 20, color: Colors.white),
            ),
          ),
        ),
      );

  testWidgets('keeps to the height of the text it stands in for', (
    tester,
  ) async {
    await pumpDots(tester, still: true);

    expect(tester.getSize(find.byType(LoadingDots)).height, 20);
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
  });

  testWidgets('moves while it waits', (tester) async {
    await pumpDots(tester);

    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('holds still under reduced motion', (tester) async {
    await pumpDots(tester, still: true);

    expect(tester.hasRunningAnimations, isFalse);
  });
}
