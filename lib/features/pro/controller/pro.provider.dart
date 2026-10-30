import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../common/config/env.dart';
import '../data/pro.repository.impl.dart';
import '../domain/pro.repository.dart';

part 'pro.provider.g.dart';

/// Every provider for the Pro feature lives in this file (see `docs/05`).

/// RevenueCat when this build has a key for its store; otherwise Pro is not
/// for sale and nothing is locked.
@Riverpod(keepAlive: true)
ProRepository proRepository(Ref ref) {
  final String? key = RevenueCatProRepository.keyFor(
    apple: Env.maybeRead(Env.revenueCatAppleKeyEnv),
    google: Env.maybeRead(Env.revenueCatGoogleKeyEnv),
  );

  return key == null
      ? const UnavailableProRepository()
      : RevenueCatProRepository(apiKey: key);
}
