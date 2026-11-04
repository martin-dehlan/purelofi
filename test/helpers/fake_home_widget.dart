import 'package:purelofi/features/player/domain/home_widget.service.dart';

/// The widgets in memory (#144).
class FakeHomeWidgetService implements HomeWidgetService {
  final List<WidgetSnapshot> shown = <WidgetSnapshot>[];

  @override
  Future<void> show(WidgetSnapshot snapshot) async => shown.add(snapshot);
}
