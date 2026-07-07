import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:home_widget/home_widget.dart';
import 'auth_service.dart';

/// Decide si un toque rápido del widget debe ignorarse por ser un doble toque
/// (dos KKs con dos toques nerviosos). Pura para poder testearla. Un reloj que
/// retrocede (nowMillis < último) no bloquea el registro.
bool shouldIgnoreQuickTap({
  required String? lastAcceptedMillisRaw,
  required int nowMillis,
  int windowMillis = 10000,
}) {
  final last = int.tryParse(lastAcceptedMillisRaw ?? '');
  if (last == null) return false;
  final delta = nowMillis - last;
  return delta >= 0 && delta < windowMillis;
}

/// Estado del botón armado del widget «La Mojona»: `true` si el toque actual
/// debe CONFIRMAR el registro (estaba armado y dentro de la ventana), `false`
/// si debe (re)armar el botón. Pura para poder testearla.
bool mojonaTapConfirms({
  required String? armedMillisRaw,
  required int nowMillis,
  int windowMillis = 5000,
}) {
  final armed = int.tryParse(armedMillisRaw ?? '');
  if (armed == null) return false;
  final delta = nowMillis - armed;
  return delta >= 0 && delta < windowMillis;
}

/// Puente app → widgets de escritorio: publica en las SharedPreferences de
/// home_widget los datos que pintan los providers Android (racha, contadores,
/// última KK, ranking) y fuerza su re-render. No-op en mock/web/no-Android.
///
/// Todos los valores se guardan como String: el canal guarda los int de Dart
/// como Integer o Long según el tamaño y en Kotlin un getInt/getLong
/// equivocado revienta; con getString no hay ambigüedad.
class WidgetDataService {
  // Nombres de clase de los providers Android (deben coincidir con Kotlin)
  static const List<String> providers = [
    'PoopWidgetProvider',
    'MojonaWidgetProvider',
    'VigiaWidgetProvider',
    'PodioWidgetProvider',
    'TronoWidgetProvider',
  ];

  static bool get _enabled =>
      !useMockData && !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Re-renderiza todos los diseños (los no colocados se ignoran sin coste).
  static Future<void> updateAllWidgets() async {
    if (!_enabled) return;
    for (final name in providers) {
      try {
        await HomeWidget.updateWidget(androidName: name);
      } catch (e) {
        debugPrint('Error actualizando widget $name: $e');
      }
    }
  }

  /// Estado del último registro rápido, para la línea inferior del Express:
  /// [status] es 'ok' | 'offline' | 'nosession'.
  static Future<void> saveLastStatus(String status, {DateTime? lastPoop}) async {
    if (!_enabled) return;
    try {
      await HomeWidget.saveWidgetData<String>('lastStatus', status);
      if (lastPoop != null) {
        await HomeWidget.saveWidgetData<String>(
            'lastPoopMillis', '${lastPoop.millisecondsSinceEpoch}');
      }
    } catch (e) {
      debugPrint('Error guardando estado del widget: $e');
    }
  }

  /// Recalcula y publica todos los datos de los widgets con UNA query (el
  /// ranking, que incluye el doc propio; racha y contadores salen de
  /// `achStats`, mantenido por el batch de addEvent). Llamar al abrir la app
  /// y tras registrar/borrar una KK.
  static Future<void> refresh() async {
    if (!_enabled) return;
    try {
      final uid = AuthService().currentUser?.uid;
      if (uid == null) return;

      final snap = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('poopCount', descending: true)
          .limit(50)
          .get();

      Map<String, dynamic>? me;
      int position = 0;
      final top = <Map<String, dynamic>>[];
      for (int i = 0; i < snap.docs.length; i++) {
        final data = snap.docs[i].data();
        if (i < 3) {
          top.add({
            'name': data['username'] ?? 'Anónimo',
            'count': data['poopCount'] ?? 0,
          });
        }
        if (snap.docs[i].id == uid) {
          me = data;
          position = i + 1;
        }
      }
      if (me == null) return;

      final now = DateTime.now();
      final achStats = (me['achStats'] as Map<String, dynamic>?) ?? {};
      final todayKey = '${now.year}-${now.month}-${now.day}';
      final monthKey = '${now.year}-${now.month}';
      final todayCount = achStats['todayKey'] == todayKey
          ? (achStats['todayCount'] as num?)?.toInt() ?? 0
          : 0;
      final monthCounts =
          (achStats['monthCounts'] as Map<String, dynamic>?) ?? {};
      final monthCount = (monthCounts[monthKey] as num?)?.toInt() ?? 0;
      final lastPoop = (me['lastPoop'] as Timestamp?)?.toDate();

      await HomeWidget.saveWidgetData<String>(
          'streak', '${me['currentStreak'] ?? 0}');
      await HomeWidget.saveWidgetData<String>('todayCount', '$todayCount');
      await HomeWidget.saveWidgetData<String>('monthCount', '$monthCount');
      await HomeWidget.saveWidgetData<String>(
          'totalCount', '${me['poopCount'] ?? 0}');
      if (lastPoop != null) {
        await HomeWidget.saveWidgetData<String>(
            'lastPoopMillis', '${lastPoop.millisecondsSinceEpoch}');
      }
      await HomeWidget.saveWidgetData<String>('lastStatus', 'ok');
      await HomeWidget.saveWidgetData<String>('rankPosition', '$position');
      await HomeWidget.saveWidgetData<String>('rankTop', jsonEncode(top));

      await updateAllWidgets();
    } catch (e) {
      // Los widgets son secundarios: un fallo aquí nunca debe romper la app.
      debugPrint('Error refrescando datos de widgets: $e');
    }
  }
}
