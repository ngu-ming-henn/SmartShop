import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local notifications (Spark-plan approach, design doc 4.2): shown from
/// Firestore listeners while the app is open or in the background.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Turned off from the Settings screen.
  bool enabled = true;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'smartshop_alerts',
      'SmartShop alerts',
      channelDescription: 'Order ready, Save Food deals and stock alerts',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> init() async {
    if (!_supported) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
  }

  /// Android 13+ asks the user once.
  Future<void> requestPermission() async {
    if (!_ready) return;
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_ready || !enabled) return;
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _details,
    );
  }
}
