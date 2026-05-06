import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

class NotifyService {
  final notifications = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await notifications.initialize(
      const InitializationSettings(android: android, iOS: DarwinInitializationSettings()),
    );

    const channel = AndroidNotificationChannel(
      'important_channel', 'Напоминания',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    await notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
  }

  Future<void> cancel(int id) async {
    await notifications.cancel(id % 100000);
    print("LOG: Уведомление $id отменено");
  }

  Future<void> schedule(int id, String title, String body, DateTime time) async {
    final tzTime = tz.TZDateTime.from(time, tz.local);
    
    print("LOG: Планирую на $tzTime (ID: ${id % 100000})");

    await notifications.zonedSchedule(
      id % 100000,
      title,
      body,
      tzTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'important_channel', 'Напоминания',
          importance: Importance.max,
          priority: Priority.high,
          fullScreenIntent: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dateAndTime, 
    );
  }

  Future<void> requestPermissions() async {
    final android = notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
  }

  Future<void> showInstant() async {
    await notifications.show(123, "Тест", "Кнопка работает!", const NotificationDetails(
      android: AndroidNotificationDetails('important_channel', 'Напоминания', importance: Importance.max),
    ));
  }
}