import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(initializationSettings);
  }

  static Future<void> mostrarNotificacionTareaPendiente(int cantidad) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'studyflow_channel',
          'Recordatorios de Tareas',
          channelDescription:
              'Notificaciones sobre tareas pendientes y próximas entregas',
          importance: Importance.max,
          priority: Priority.high,
        );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.show(
      0,
      'StudyFlow - Recordatorio',
      'Tienes $cantidad tarea(s) pendiente(s) por completar.',
      notificationDetails,
    );
  }
}
