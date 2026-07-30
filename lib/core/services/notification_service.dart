import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:io' show Platform;
import '../../features/finances/models/category_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    // Use the default local timezone instead of hardcoding
    tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));

    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsDarwin = DarwinInitializationSettings();
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
    );
  }

  Future<void> requestPermissions() async {
    if (kIsWeb) return;

    if (Platform.isIOS || Platform.isMacOS) {
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();
      await androidImplementation?.requestExactAlarmsPermission();
    }
  }

  Future<void> scheduleAppointmentNotification({
    required int id,
    required String title,
    required String body,
    required DateTime appointmentDate,
  }) async {
    if (kIsWeb) return;

    // Schedule for 8:00 AM on the day of the appointment
    final scheduledDate = DateTime(
      appointmentDate.year,
      appointmentDate.month,
      appointmentDate.day,
      8,
      0,
    );

    // If the time has already passed today, don't schedule it
    if (scheduledDate.isBefore(DateTime.now())) {
      return;
    }

    final tz.TZDateTime tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'appointments_channel',
      'Compromissos',
      channelDescription: 'Lembretes diários de compromissos',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tzScheduledDate,
      notificationDetails: platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> scheduleCardNotifications(CategoryModel card) async {
    if (kIsWeb) return;
    if (card.closingDay == null && card.dueDay == null) return;

    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'cards_channel',
      'Cartões de Crédito',
      channelDescription: 'Lembretes de fechamento e vencimento',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);

    final now = DateTime.now();

    if (card.closingDay != null) {
      final closingId = card.id.hashCode ^ "closing".hashCode;
      
      // We want to schedule for 09:00 on the closingDay of every month
      final scheduledDate = DateTime(now.year, now.month, card.closingDay!, 9, 0);
      final tz.TZDateTime tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id: closingId,
        title: 'Cartão Fechando!',
        body: 'A fatura do seu cartão ${card.name} fecha hoje.',
        scheduledDate: tzScheduledDate,
        notificationDetails: platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
      );
    }

    if (card.dueDay != null) {
      final dueId = card.id.hashCode ^ "due".hashCode;
      
      // Schedule for 09:00 on the day BEFORE the dueDay
      // If dueDay is 1, it should alert on the last day of the previous month.
      // By using DateTime calculation, Dart handles month rollover automatically.
      final notificationDate = DateTime(now.year, now.month, card.dueDay!).subtract(const Duration(days: 1));
      
      final scheduledDate = DateTime(now.year, now.month, notificationDate.day, 9, 0);
      final tz.TZDateTime tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id: dueId,
        title: 'Fatura Vencendo',
        body: 'A fatura do seu cartão ${card.name} vence amanhã.',
        scheduledDate: tzScheduledDate,
        notificationDetails: platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
      );
    }
  }

  Future<void> cancelCardNotifications(String cardId) async {
    if (kIsWeb) return;
    final closingId = cardId.hashCode ^ "closing".hashCode;
    final dueId = cardId.hashCode ^ "due".hashCode;
    await _flutterLocalNotificationsPlugin.cancel(id: closingId);
    await _flutterLocalNotificationsPlugin.cancel(id: dueId);
  }

  Future<void> cancelNotification(int id) async {
    if (kIsWeb) return;
    await _flutterLocalNotificationsPlugin.cancel(id: id);
  }

  Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    await _flutterLocalNotificationsPlugin.cancelAll();
  }
}
