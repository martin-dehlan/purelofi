import 'package:purelofi/features/player/domain/focus_notifier.service.dart';

/// The focus notice in memory: what would have been shown, in order.
class FakeFocusNotifier implements FocusNotifier {
  final List<String> announced = <String>[];
  int prepared = 0;
  int cleared = 0;

  @override
  Future<void> prepare() async => prepared++;

  @override
  Future<void> announce(String text) async => announced.add(text);

  @override
  Future<void> clear() async => cleared++;
}
