import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/app_icon.widget.dart';
import 'artist_link_button.widget.dart';

/// An artist's channels as a small raised bar standing beside their
/// picture: one mark per channel, top to bottom.
///
/// It is as tall as [height] allows, which is the picture's. Most artists
/// have a few channels and they all fit in that one column. When there are
/// more, the last place holds a "more" button, and the rest unfold to the
/// left in further columns. The bar sits over the header rather than in it,
/// so unfolding moves neither the picture nor the name.
class ArtistLinksBar extends StatefulWidget {
  const ArtistLinksBar({required this.links, required this.height, super.key});

  final List<String> links;

  /// How tall the bar may be: the picture's height.
  final double height;

  @override
  State<ArtistLinksBar> createState() => _ArtistLinksBarState();
}

class _ArtistLinksBarState extends State<ArtistLinksBar> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final List<String> links = widget.links;

    // One button: the mark and its padding all round.
    final double button = context.fontL + context.spaceS * 2;
    final double inset = context.spaceXs;
    final int perColumn = math.max(
      2,
      ((widget.height - inset * 2) / button).floor(),
    );
    final bool overflows = links.length > perColumn;

    // The first column: every channel, or all but the last place, which
    // goes to the button that unfolds the rest.
    final List<String> first = overflows
        ? links.sublist(0, perColumn - 1)
        : links;
    final List<String> rest = overflows
        ? links.sublist(perColumn - 1)
        : const <String>[];

    final List<List<String>> more = <List<String>>[
      for (int i = 0; i < rest.length; i += perColumn)
        rest.sublist(i, math.min(i + perColumn, rest.length)),
    ];

    Widget column(List<Widget> children) =>
        Column(mainAxisSize: MainAxisSize.min, children: children);

    return Material(
      color: cs.surfaceContainerHighest,
      elevation: 6,
      shadowColor: cs.shadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(button / 2 + inset),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(inset),
        // Anchored at its right edge, the bar grows to the left.
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (_open)
                // The next column sits closest to the first one.
                for (final List<String> links in more.reversed)
                  column(<Widget>[
                    for (final String link in links)
                      ArtistLinkButton(url: link),
                  ]),
              column(<Widget>[
                for (final String link in first) ArtistLinkButton(url: link),
                if (overflows)
                  IconButton(
                    tooltip: _open ? 'Fewer channels' : 'More channels',
                    onPressed: () => setState(() => _open = !_open),
                    padding: EdgeInsets.all(context.spaceS),
                    icon: AppIcon(
                      _open ? AppGlyph.chevron : AppGlyph.more,
                      size: context.fontL,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
