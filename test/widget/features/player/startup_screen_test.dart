import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/features/player/presentation/widgets/startup_screen.widget.dart';

import '../../../helpers/pump_routed_app.dart';

void main() {
  /// The blocks drawn in the primary colour: the filled part of the bar.
  int litBlocks(WidgetTester tester) {
    final Color primary = Theme.of(
      tester.element(find.byType(StartupScreen)),
    ).colorScheme.primary;

    return tester
        .widgetList<ColoredBox>(
          find.descendant(
            of: find.byType(Row),
            matching: find.byType(ColoredBox),
          ),
        )
        .where((ColoredBox box) => box.color == primary)
        .length;
  }

  testWidgets('shows the wordmark', (tester) async {
    await tester.pumpProviderApp(child: const StartupScreen(progress: 0.5));

    expect(find.text('PureLofi'), findsOneWidget);
    expect(find.text('tuning in'), findsOneWidget);
  });

  testWidgets('fills the bar in whole blocks', (tester) async {
    await tester.pumpProviderApp(child: const StartupScreen(progress: 0.5));

    expect(litBlocks(tester), 6);
  });

  testWidgets('a full bar lights every block', (tester) async {
    await tester.pumpProviderApp(child: const StartupScreen(progress: 1));

    expect(litBlocks(tester), 12);
  });

  testWidgets('with nothing to count, one block walks', (tester) async {
    await tester.pumpProviderApp(child: const StartupScreen());

    expect(litBlocks(tester), 1);
    final Finder lit = find.byWidgetPredicate(
      (Widget w) =>
          w is ColoredBox &&
          w.color ==
              Theme.of(
                tester.element(find.byType(StartupScreen)),
              ).colorScheme.primary,
    );
    final Offset before = tester.getCenter(lit);

    await tester.pump(const Duration(milliseconds: 600));

    expect(litBlocks(tester), 1);
    expect(tester.getCenter(lit), isNot(before));
  });

  testWidgets('tells a screen reader how far it is', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpProviderApp(child: const StartupScreen(progress: 0.5));

    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel('Loading')).value, '50%');
    handle.dispose();
  });
}
