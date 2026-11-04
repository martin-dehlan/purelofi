import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/analytics/analytics.provider.dart';
import '../../../../common/analytics/analytics.service.dart';
import '../../../../common/utils/app_links.dart';
import '../../../../common/utils/responsive.dart';
import '../../domain/artist.entity.dart';
import '../../domain/artist_link.dart';

/// "Support Masso" on an artist's page (#152): straight to where they take
/// support, outside the app. The line under it says so plainly — the money
/// goes to the artist, PureLofi only points the way.
class SupportArtistButton extends ConsumerWidget {
  const SupportArtistButton({required this.artist, super.key});

  final ArtistEntity artist;

  /// Opens [artist]'s support page and notes it, so artists can be shown
  /// what PureLofi sends them.
  static Future<void> open(WidgetRef ref, ArtistEntity artist) async {
    final String? url = artist.supportUrl;
    if (url == null) return;
    unawaited(
      ref.read(analyticsServiceProvider).capture(
        AnalyticsEvents.artistSupportOpened,
        <String, Object>{'artist_id': artist.id},
      ),
    );
    await AppLinks.openUrl(url);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? url = artist.supportUrl;
    if (url == null) return const SizedBox.shrink();

    final ColorScheme cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        OutlinedButton(
          onPressed: () => unawaited(open(ref, artist)),
          style: OutlinedButton.styleFrom(
            minimumSize: Size.fromHeight(context.screenHeight * 0.06),
            shape: const StadiumBorder(),
            side: BorderSide(color: cs.primary),
            foregroundColor: cs.primary,
          ),
          child: Text(
            'Support ${artist.name}',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: context.fontM,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(height: context.spaceXs),
        Text(
          'Opens ${supportPlatform(url)}. It goes straight to the artist.',
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: context.fontS),
        ),
      ],
    );
  }
}
