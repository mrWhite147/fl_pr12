import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    
    try {
      tz.setLocalLocation(tz.getLocation('Europe/Moscow'));
      print("NotificationService: Москва (GMT+3) установлена");
    } catch (e) {
      print("Ошибка часового пояса: $e");
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (details) {
        print("Пользователь открыл уведомление: ${details.id}");
      },
    );
  }

  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      
      if (await Permission.scheduleExactAlarm.isDenied) {
        print("Запрос доступа к точным будильникам...");
        await Permission.scheduleExactAlarm.request();
      }

      return status.isGranted;
    } else if (Platform.isIOS) {
      final result = await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return result ?? false;
    }
    return false;
  }

  NotificationDetails _notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'reminder_channel_v1',
        'Напоминания',
        channelDescription: 'Уведомления о ваших задачах',
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.reminder,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  Future<void> showInstantNotification() async {
    await _plugin.show(
      999,
      'Уведомление',
      'Уведомление',
      _notificationDetails(),
    );
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    final scheduledAt = tz.TZDateTime.from(scheduledDate, tz.local);

    print("--- ПЛАНИРОВАНИЕ ---");
    print("Сейчас (МСК): $now");
    print("Цель (МСК): $scheduledAt");

    if (scheduledAt.isBefore(now)) {
      print("Ошибка: время напоминания в прошлом");
      return;
    }

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledAt,
      _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    print("Напоминание $id успешно создано!");
  }

  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
    print("Уведомление $id удалено из системного планировщика");
  }
}