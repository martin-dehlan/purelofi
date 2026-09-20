import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'common/config/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Env.load();
  // `publishableKey` is the current name for the slot the legacy anon key
  // occupies; `anonKey` is deprecated. The .env key stays SUPABASE_ANON_KEY.
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
  );

  runApp(const ProviderScope(child: PureLofiApp()));
}
