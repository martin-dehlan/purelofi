import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purelofi/features/player/domain/artist.entity.dart';
import 'package:purelofi/features/player/presentation/widgets/artist_avatar.widget.dart';

void main() {
  const ArtistEntity masso = ArtistEntity(id: 'masso', name: 'Masso');

  Size circleOf(WidgetTester tester) => tester.getSize(find.byType(ClipOval));

  Future<void> pump(WidgetTester tester, Widget child) =>
      tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));

  testWidgets('is a circle of its size where there is room', (tester) async {
    await pump(
      tester,
      const Center(child: ArtistAvatar(artist: masso, size: 80)),
    );

    expect(circleOf(tester), const Size(80, 80));
  });

  testWidgets('in a ListTile, too big for it, it shrinks and stays round', (
    tester,
  ) async {
    await pump(
      tester,
      const ListTile(
        leading: ArtistAvatar(artist: masso, size: 70),
        title: Text('Masso'),
        subtitle: Text('Artist'),
      ),
    );

    final Size circle = circleOf(tester);
    expect(circle.width, circle.height);
    expect(circle.height, lessThanOrEqualTo(56));
  });

  testWidgets('squeezed between two sides, it takes the shorter', (
    tester,
  ) async {
    await pump(
      tester,
      const Center(
        child: SizedBox(
          width: 60,
          height: 40,
          child: ArtistAvatar(artist: masso, size: 60),
        ),
      ),
    );

    expect(circleOf(tester), const Size(40, 40));
  });
}
