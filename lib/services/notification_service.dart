import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

class NotifyService {
  final _plugin = FlutterLocalNotificationsPlugin();

  // 1. Инициализация сервиса
  Future<void> init() async {
    // Настройка часовых поясов (Москва GMT+3)
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Moscow'));

    // Иконка для уведомлений (должна быть в android/app/src/main/res/mipmap)
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: DarwinInitializationSettings(),
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        print("Пользователь нажал на уведомление");
      },
    );
  }

  // 2. Запрос разрешений (Критично для Android 12/13/14)
  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      // Запрос на показ уведомлений (текст/звук)
      await Permission.notification.request();

      // Запрос на "Точные будильники" (Android 12+)
      // Если это разрешение не дано, метод schedule вызовет ошибку
      if (await Permission.scheduleExactAlarm.isDenied) {
        await Permission.scheduleExactAlarm.request();
      }
    }
  }

  // Вспомогательный метод для настроек канала (Максимальный приоритет)
  NotificationDetails _details() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'reminder_channel_v3', // ID канала
        'Напоминания',          // Имя канала
        channelDescription: 'Уведомления о ваших задачах',
        importance: Importance.max, // Чтобы всплывало баннером
        priority: Priority.high,    // Высокий приоритет
        fullScreenIntent: true,     // Для пробития защиты Xiaomi
        playSound: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  // 3. Мгновенное уведомление (Кнопка-молния)
  Future<void> showInstant() async {
    await _plugin.show(
      0, 
      'Тест системы! ⚡', 
      'Мгновенное уведомление работает по МСК.', 
      _details(),
    );
  }

  // 4. Планирование уведомления (Метод из твоего рабочего примера)
  Future<void> schedule(int id, String title, String body, DateTime date) async {
    // Конвертируем обычный DateTime в TZDateTime (Москва)
    final tzDate = tz.TZDateTime.from(date, tz.local);

    // Лог для проверки в консоли
    print("--- ПЛАНИРОВАНИЕ ---");
    print("Сейчас (МСК): ${tz.TZDateTime.now(tz.local)}");
    print("Цель (МСК): $tzDate");

    // Если время уже прошло, не планируем
    if (tzDate.isBefore(tz.TZDateTime.now(tz.local))) {
      print("Ошибка: Время уже прошло.");
      return;
    }

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzDate,
      _details(),
      // exactAllowWhileIdle позволяет сработать даже в режиме экономии энергии
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    print("Уведомление $id успешно запланировано!");
  }

  // 5. Отмена уведомления (при удалении карточки)
  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
    print("Системное уведомление $id отменено");
  }
}