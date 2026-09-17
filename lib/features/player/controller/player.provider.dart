import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../common/config/supabase.provider.dart';
import '../data/content.api.dart';
import '../data/content.repository.impl.dart';
import '../domain/content.repository.dart';

part 'player.provider.g.dart';

/// Every provider for the player feature lives in this file (see `docs/05`).

@Riverpod(keepAlive: true)
ContentApi contentApi(Ref ref) => ContentApi(ref.watch(supabaseClientProvider));

@Riverpod(keepAlive: true)
ContentRepository contentRepository(Ref ref) =>
    ContentRepositoryImpl(api: ref.watch(contentApiProvider));
