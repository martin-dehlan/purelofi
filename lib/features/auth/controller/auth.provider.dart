import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../common/config/env.dart';
import '../../../common/config/supabase.provider.dart';
import '../data/apple_identity.service.impl.dart';
import '../data/auth.repository.impl.dart';
import '../data/google_identity.service.impl.dart';
import '../domain/auth.repository.dart';

part 'auth.provider.g.dart';

/// Every provider for the auth feature lives in this file (see `docs/05`).

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  final SupabaseClient client = ref.watch(supabaseClientProvider);

  return AuthRepositoryImpl(
    auth: client.auth,
    apple: const AppleIdentityServiceImpl(),
    google: GoogleIdentityServiceImpl(
      webClientId: Env.maybeRead(Env.googleWebClientIdEnv),
      iosClientId: Env.maybeRead(Env.googleIosClientIdEnv),
    ),
    openGoogleInBrowser: () async {
      await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: AuthRepositoryImpl.callbackUrl,
      );
    },
    // `delete_account()` deletes the caller and nobody else; see the
    // migration of the same name.
    deleteOwnAccount: () async {
      await client.rpc<void>('delete_account');
    },
  );
}
