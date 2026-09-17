import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The app shell. A lo-fi player is a night-time app, so it is dark by
/// default and the scene video stays the brightest thing on screen
/// (see `docs/09`).
class PureLofiApp extends ConsumerWidget {
  const PureLofiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'PureLofi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      // Placeholder until the player screen lands (issue #5).
      home: const Scaffold(body: SizedBox.expand()),
    );
  }
}
