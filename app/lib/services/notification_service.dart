import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(settings);
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    int id = 0,
  }) async {
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
    );

    await _notificationsPlugin.show(id, title, body, details);
  }

  static Future<void> showCourseAvailableNotification(
    String courseName,
    int available,
    int limitCount,
  ) async {
    final title = '课程余量提醒';
    final body = '$courseName 现在有余量！剩余 $available/$limitCount';

    await showNotification(
      title: title,
      body: body,
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000, // 使用时间戳作为ID
    );
  }
}
