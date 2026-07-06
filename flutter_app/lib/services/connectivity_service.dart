import 'package:connectivity_plus/connectivity_plus.dart';

import 'auth_service.dart'; // useMockData

/// Detección de conectividad de red. Nota: `connectivity_plus` informa del
/// estado de la interfaz (wifi/datos/ninguna), no de que haya internet real,
/// que es suficiente para avisar "sin conexión". La persistencia offline de
/// Firestore ya encola las escrituras; esto es solo señalización a la UI.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();

  bool _hasNetwork(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  /// Emite `true` cuando hay conexión y `false` cuando no, empezando por el
  /// estado actual (el `onConnectivityChanged` nativo no emite el inicial). En
  /// modo simulación no emite nada (no interesa el banner en Windows/tests).
  Stream<bool> get onStatusChange async* {
    if (useMockData) return;
    yield await isOnline();
    yield* _connectivity.onConnectivityChanged.map(_hasNetwork);
  }

  Future<bool> isOnline() async {
    if (useMockData) return true;
    try {
      return _hasNetwork(await _connectivity.checkConnectivity());
    } catch (_) {
      return true; // ante la duda, no bloquear acciones
    }
  }
}
