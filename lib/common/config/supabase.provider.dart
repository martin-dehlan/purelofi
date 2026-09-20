import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'supabase.provider.g.dart';

/// The app-wide Supabase client.
///
/// Read-only in the MVP: the app streams public content and never writes.
/// Initialised in `main.dart` before the app starts, so reading
/// `Supabase.instance` here is safe.
@Riverpod(keepAlive: true)
SupabaseClient supabaseClient(Ref ref) => Supabase.instance.client;
