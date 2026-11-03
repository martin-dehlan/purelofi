import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/features/player/presentation/widgets/artist_links_bar.widget.dart';

void main() {
  Future<void> pumpBar(WidgetTester tester, List<String> links) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: ArtistLinksBar(links: links, height: 120),
          ),
        ),
      ),
    );
  }

  const List<String> few = <String>[
    'https://youtube.com/@ada',
    'https://instagram.com/ada',
  ];
  const List<String> many = <String>[
    'https://youtube.com/@ada',
    'https://instagram.com/ada',
    'https://open.spotify.com/artist/ada',
    'https://soundcloud.com/ada',
    'https://tiktok.com/@ada',
    'https://ada.example',
  ];

  testWidgets('a few channels stand in one column, no more button', (
    tester,
  ) async {
    await pumpBar(tester, few);

    expect(find.byTooltip('More channels'), findsNothing);
    final Offset first = tester.getCenter(find.byTooltip('YouTube'));
    final Offset second = tester.getCenter(find.byTooltip('Instagram'));
    expect(second.dx, first.dx);
    expect(second.dy, greaterThan(first.dy));
  });

  testWidgets('more than fit unfold to the left and fold back', (tester) async {
    await pumpBar(tester, many);

    expect(find.byTooltip('More channels'), findsOneWidget);
    expect(find.byTooltip('Website'), findsNothing);
    final double right = tester.getTopRight(find.byType(ArtistLinksBar)).dx;

    await tester.tap(find.byTooltip('More channels'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Website'), findsOneWidget);
    // Grown to the left: the right edge stays where it was.
    expect(tester.getTopRight(find.byType(ArtistLinksBar)).dx, right);
    expect(
      tester.getCenter(find.byTooltip('Website')).dx,
      lessThan(tester.getCenter(find.byTooltip('YouTube')).dx),
    );

    await tester.tap(find.byTooltip('Fewer channels'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Website'), findsNothing);
  });
}
