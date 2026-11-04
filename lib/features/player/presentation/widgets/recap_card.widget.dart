import 'package:flutter/material.dart';

import '../../../../common/utils/app_fonts.dart';
import '../../domain/listening_stats.dart';
import '../../domain/scene.entity.dart';
import 'scene_thumbnail.widget.dart';

/// The week as a picture to share (#151): the room most listened in, how
/// long, and who. Laid out on a 9:16 card in proportions of its own width,
/// so it reads the same at any size it is drawn or captured.
class RecapCard extends StatelessWidget {
  const RecapCard({
    required this.stats,
    required this.width,
    this.room,
    this.topTrack,
    super.key,
  });

  final ListeningStats stats;
  final double width;
  final SceneEntity? room;
  final String? topTrack;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final double unit = width / 100;
    final SceneEntity? room = this.room;

    TextStyle text(double size, {bool strong = false, bool dim = false}) =>
        TextStyle(
          color: dim ? cs.onSurfaceVariant : cs.onSurface,
          fontSize: unit * size,
          fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
          height: 1.2,
        );

    final Widget content = SizedBox(
      width: unit * 84,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('My week in', style: text(5, dim: true)),
          Text(
            'PureLofi',
            style: text(
              9,
              strong: true,
            ).copyWith(fontFamily: AppFonts.wordmark),
          ),
          SizedBox(height: unit * 6),
          if (room != null) ...<Widget>[
            SceneThumbnail(scene: room, size: unit * 60),
            SizedBox(height: unit * 3),
            Text('Mostly in ${room.title}', style: text(5), maxLines: 1),
          ],
          SizedBox(height: unit * 10),
          Text(
            listeningTimeLabel(stats.total),
            style: text(11, strong: true).copyWith(color: cs.primary),
          ),
          Text('of real lo-fi', style: text(5, dim: true)),
          SizedBox(height: unit * 4),
          if (stats.topArtist case final String artist) ...<Widget>[
            Text('Most with', style: text(4, dim: true)),
            Text(artist, style: text(6, strong: true), maxLines: 1),
            SizedBox(height: unit * 2),
          ],
          if (topTrack case final String track) ...<Widget>[
            Text('On repeat', style: text(4, dim: true)),
            Text(track, style: text(6, strong: true), maxLines: 1),
          ],
          SizedBox(height: unit * 10),
          Text('purelofi.app', style: text(4, dim: true)),
        ],
      ),
    );

    return Container(
      width: width,
      height: width * 16 / 9,
      color: cs.surface,
      padding: EdgeInsets.all(unit * 8),
      // Scaled down rather than cut off if a font runs taller than planned
      // at some size: the card is a picture, it must always be whole.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topLeft,
        child: content,
      ),
    );
  }
}
