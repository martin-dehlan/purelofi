import 'package:home_widget/home_widget.dart';

import '../domain/home_widget.service.dart';

/// The `home_widget` bridge: shared preferences on Android, the App Group
/// on iOS. A widget that cannot be told is no reason to bother the
/// listener, so every failure is swallowed.
class HomeWidgetServiceImpl implements HomeWidgetService {
  HomeWidgetServiceImpl();

  bool _grouped = false;

  @override
  Future<void> show(WidgetSnapshot s) async {
    try {
      if (!_grouped) {
        await HomeWidget.setAppGroupId(WidgetKeys.appGroup);
        _grouped = true;
      }
      await HomeWidget.saveWidgetData<String>(WidgetKeys.room, s.room);
      await HomeWidget.saveWidgetData<String>(WidgetKeys.track, s.track);
      await HomeWidget.saveWidgetData<String>(WidgetKeys.artist, s.artist);
      await HomeWidget.saveWidgetData<String>(WidgetKeys.cover, s.coverPath);
      await HomeWidget.saveWidgetData<bool>(WidgetKeys.playing, s.isPlaying);
      await HomeWidget.saveWidgetData<String>(WidgetKeys.accent, s.accent);
      await HomeWidget.updateWidget(
        qualifiedAndroidName: WidgetKeys.androidProvider,
        iOSName: WidgetKeys.iosKind,
      );
    } on Object {
      // The widget shows what it last knew.
    }
  }
}
