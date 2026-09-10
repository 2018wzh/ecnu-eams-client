import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform != TargetPlatform.windows;
  static String? initializationError;
  static Future<void> requestPermission() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final allowed = await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      if (allowed == false) throw StateError('通知权限未开启，请在应用内查看监控结果');
    }
  }

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    if (!supported) return;
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
      linux: LinuxInitializationSettings(defaultActionName: '查看'),
    );

    try {
      await _notificationsPlugin.initialize(settings);
    } catch (e) {
      initializationError = '系统通知初始化失败: $e';
      debugPrint(initializationError);
    }
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    int id = 0,
  }) async {
    if (!supported) return;
    if (initializationError != null) throw StateError(initializationError!);
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'course_monitor_channel',
      '课程监控通知',
      channelDescription: '课程监控余量通知',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
      linux: LinuxNotificationDetails(),
    );

    await _notificationsPlugin.show(id, title, body, details);
  }

  static Future<void> showCourseAvailableNotification(
    String courseName,
    int available,
    int limitCount,
  ) async {
    const title = '课程余量提醒';
    final body = '$courseName 现在有余量！剩余 $available/$limitCount';

    await showNotification(
      title: title,
      body: body,
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000, // 使用时间戳作为ID
    );
  }
}
