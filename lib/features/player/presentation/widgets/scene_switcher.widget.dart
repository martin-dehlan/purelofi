import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/utils/app_assets.dart';
import '../../../../common/utils/responsive.dart';
import '../../../../common/widgets/pixel_icon.widget.dart';
import 'scene_switcher_sheet.widget.dart';

/// Opens the scene list. Switching scenes is a state change, not a route
/// (see `docs/08`).
class SceneSwitcher extends ConsumerWidget {
  const SceneSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      button: true,
      label: 'Switch scene',
      child: GestureDetector(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          backgroundColor: Theme.of(context).colorScheme.surface,
          builder: (_) => const SceneSwitcherSheet(),
        ),
        child: PixelIcon(
          asset: AppAssets.sceneSwitchIcon,
          size: context.screenWidth * 0.09,
        ),
      ),
    );
  }
}
