import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../domain/focus_notifier.service.dart';

/// The focus notice through the platform's notifications: a channel of its
/// own on Android that vibrates and stays silent (the chime is already in
/// the music), a banner without sound on iOS. Anything the platform
/// refuses is let go: the chime and the quieter music still tell.
class FocusNotifierImpl implements FocusNotifier {
  FocusNotifierImpl([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<bool>? _ready;

  static const int _id = 137;

  static const AndroidNotificationDetails _android = AndroidNotificationDetails(
    'focus',
    'Focus timer',
    channelDescription: 'When a focus stretch or a break ends.',
    importance: Importance.high,
    priority: Priority.high,
    playSound: false,
    enableVibration: true,
    icon: 'ic_notification',
  );

  static const DarwinNotificationDetails _darwin = DarwinNotificationDetails(
    presentAlert: true,
    presentBanner: true,
    presentList: true,
    presentSound: false,
  );

  Future<bool> _init() => _ready ??= () async {
    try {
      return await _plugin.initialize(
            settings: const InitializationSettings(
              android: AndroidInitializationSettings('ic_notification'),
              iOS: DarwinInitializationSettings(
                requestAlertPermission: false,
                requestBadgePermission: false,
                requestSoundPermission: false,
              ),
            ),
          ) ??
          false;
    } on Object {
      return false;
    }
  }();

  @override
  Future<void> prepare() async {
    if (!await _init()) return;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true);
    } on Object {
      // Refused or not asked: the chime still tells.
    }
  }

  @override
  Future<void> announce(String text) async {
    // Felt in the hand while the app is open; the notification buzzes
    // when it is not.
    try {
      await HapticFeedback.vibrate();
    } on Object {
      // No vibrator, nothing to feel.
    }
    if (!await _init()) return;
    try {
      await _plugin.show(
        id: _id,
        title: text,
        notificationDetails: const NotificationDetails(
          android: _android,
          iOS: _darwin,
        ),
      );
    } on Object {
      // Not allowed to notify: the chime still tells.
    }
  }

  @override
  Future<void> clear() async {
    if (!await _init()) return;
    try {
      await _plugin.cancel(id: _id);
    } on Object {
      // Nothing shown, nothing to take away.
    }
  }
}
