import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

import '../firebase_options.dart';
import 'auth_service.dart'; // Para useMockData
import 'database_service.dart';

/// Handler de mensajes en segundo plano. Debe ser una función de nivel superior
/// con @pragma('vm:entry-point') y registrarse en main() con
/// FirebaseMessaging.onBackgroundMessage antes de runApp. Los mensajes con
/// bloque `notification` los pinta el sistema operativo automáticamente; aquí
/// solo garantizamos que Firebase esté inicializado en el isolate de background.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {
    // Ya inicializado en este isolate.
  }
  debugPrint('Mensaje push en segundo plano: ${message.messageId}');
}

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized || useMockData) return;

    // Solicitar permisos en iOS y Android 13+
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('Permiso de notificaciones concedido');
    } else {
      debugPrint('Permiso de notificaciones denegado o pendiente');
    }

    // Configurar notificaciones locales (para mostrarlas en primer plano)
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await _localNotificationsPlugin.initialize(
      settings: initializationSettings,
    );

    // Escuchar mensajes en primer plano (el SO no los muestra solo)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        _showLocalNotification(notification.title, notification.body);
      }
    });

    _initialized = true;
  }

  /// Guarda el token FCM del dispositivo en el doc del usuario y se suscribe a
  /// sus renovaciones. Necesario para que las Cloud Functions sepan a dónde
  /// enviar los avisos. No hace nada en modo simulación.
  Future<void> registerDeviceForUser(String uid) async {
    if (useMockData) return;
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        await DatabaseService().saveFcmToken(uid, token);
      }
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        DatabaseService().saveFcmToken(uid, newToken);
      });
    } catch (e) {
      debugPrint('Error al registrar el token FCM: $e');
    }
  }

  Future<void> _showLocalNotification(String? title, String? body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'kkpenco_channel_id',
      'KKpenco Notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      color: Color(0xFF5D4037),
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);

    await _localNotificationsPlugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000 % 2147483647,
      title: title ?? 'KKpenco',
      body: body,
      notificationDetails: platformChannelSpecifics,
    );
  }

  // Permite programar un recordatorio local
  Future<void> scheduleLocalReminder(String title, String body, Duration delay) async {
    // Usando un retardo simple. Para alarmas exactas se requiere timezone.
    // Esto es un ejemplo sencillo que muestra la notificación después de X tiempo (simulado vía Future.delayed si la app está abierta)
    // En producción se usa zonedSchedule de flutter_local_notifications.
    Future.delayed(delay, () {
      _showLocalNotification(title, body);
    });
  }

  Future<String?> getToken() async {
    return await _firebaseMessaging.getToken();
  }
}
