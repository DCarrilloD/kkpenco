import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Asegurarse de que Firebase esté inicializado en el isolate en segundo plano
  // Firebase.initializeApp() debería llamarse antes, pero asumimos que el SDK 
  // maneja la recepción inicial o se configura en main.dart.
  debugPrint("Handling a background message: ${message.messageId}");
}

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    // Solicitar permisos en iOS y Android 13+
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
    } else {
      debugPrint('User declined or has not accepted permission');
    }

    // Configurar notificaciones locales
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await _localNotificationsPlugin.initialize(
      settings: initializationSettings,
    );

    // Configurar recepción en segundo plano
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Escuchar mensajes en primer plano
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint('Message also contained a notification: ${message.notification}');
        _showLocalNotification(message.notification!.title, message.notification!.body);
      }
    });

    _initialized = true;
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
