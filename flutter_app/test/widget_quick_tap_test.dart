import 'package:flutter_test/flutter_test.dart';
import 'package:kkpenco/services/widget_data_service.dart';

/// Pruebas de las decisiones puras del widget de escritorio (PLAN_WIDGET 1.2
/// y D2): guardia anti-doble-toque y armado en dos toques de «La Mojona».
void main() {
  group('shouldIgnoreQuickTap (anti-doble-toque)', () {
    test('sin registro previo no bloquea', () {
      expect(
        shouldIgnoreQuickTap(lastAcceptedMillisRaw: null, nowMillis: 1000),
        isFalse,
      );
      expect(
        shouldIgnoreQuickTap(lastAcceptedMillisRaw: '', nowMillis: 1000),
        isFalse,
      );
      expect(
        shouldIgnoreQuickTap(lastAcceptedMillisRaw: 'basura', nowMillis: 1000),
        isFalse,
      );
    });

    test('segundo toque dentro de la ventana se ignora', () {
      expect(
        shouldIgnoreQuickTap(lastAcceptedMillisRaw: '10000', nowMillis: 12000),
        isTrue,
      );
      // Justo en el borde inferior (mismo instante)
      expect(
        shouldIgnoreQuickTap(lastAcceptedMillisRaw: '10000', nowMillis: 10000),
        isTrue,
      );
    });

    test('toque pasada la ventana se acepta', () {
      expect(
        shouldIgnoreQuickTap(lastAcceptedMillisRaw: '10000', nowMillis: 20000),
        isFalse,
      );
    });

    test('un reloj que retrocede no bloquea el registro', () {
      expect(
        shouldIgnoreQuickTap(lastAcceptedMillisRaw: '50000', nowMillis: 40000),
        isFalse,
      );
    });

    test('la ventana es configurable', () {
      expect(
        shouldIgnoreQuickTap(
          lastAcceptedMillisRaw: '0',
          nowMillis: 2500,
          windowMillis: 2000,
        ),
        isFalse,
      );
      expect(
        shouldIgnoreQuickTap(
          lastAcceptedMillisRaw: '0',
          nowMillis: 1500,
          windowMillis: 2000,
        ),
        isTrue,
      );
    });
  });

  group('mojonaTapConfirms (armado en dos toques)', () {
    test('sin armado previo, el toque arma (no confirma)', () {
      expect(mojonaTapConfirms(armedMillisRaw: null, nowMillis: 1000), isFalse);
      expect(mojonaTapConfirms(armedMillisRaw: '', nowMillis: 1000), isFalse);
    });

    test('segundo toque dentro de la ventana confirma', () {
      expect(
        mojonaTapConfirms(armedMillisRaw: '10000', nowMillis: 13000),
        isTrue,
      );
    });

    test('toque con el armado caducado vuelve a armar (no confirma)', () {
      expect(
        mojonaTapConfirms(armedMillisRaw: '10000', nowMillis: 16000),
        isFalse,
      );
    });

    test('un reloj que retrocede no confirma por accidente', () {
      expect(
        mojonaTapConfirms(armedMillisRaw: '50000', nowMillis: 40000),
        isFalse,
      );
    });
  });
}
