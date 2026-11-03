import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/common/widgets/skeleton.widget.dart';

void main() {
  Future<void> pumpSkeleton(WidgetTester tester, {bool still = false}) =>
      tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(400, 800),
            ).copyWith(disableAnimations: still),
            child: const Center(child: Skeleton(width: 40, height: 12)),
          ),
        ),
      );

  testWidgets('takes the size it stands in for', (tester) async {
    await pumpSkeleton(tester, still: true);

    expect(tester.getSize(find.byType(Skeleton)), const Size(40, 12));
  });

  testWidgets('breathes while it waits', (tester) async {
    await pumpSkeleton(tester);

    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('holds still under reduced motion', (tester) async {
    await pumpSkeleton(tester, still: true);

    expect(tester.hasRunningAnimations, isFalse);
  });
}
