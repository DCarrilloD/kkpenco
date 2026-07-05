import 'package:flutter_test/flutter_test.dart';
import 'package:kkpenco/models/event.dart';

void main() {
  group('Pruebas unitarias del cálculo incremental de rachas', () {
    test('Primera deposición del usuario inicia la racha en 1', () {
      final streak = KKEvent.calculateIncrementalStreak(
        currentStreak: 0,
        previousLastPoop: null,
        newEventDate: DateTime(2026, 7, 5, 9, 30),
      );
      expect(streak, equals(1));
    });

    test('Evento el mismo día mantiene la racha', () {
      final streak = KKEvent.calculateIncrementalStreak(
        currentStreak: 3,
        previousLastPoop: DateTime(2026, 7, 5, 8, 0),
        newEventDate: DateTime(2026, 7, 5, 22, 45),
      );
      expect(streak, equals(3));
    });

    test('Evento el mismo día con racha 0 (dato legacy) la corrige a 1', () {
      final streak = KKEvent.calculateIncrementalStreak(
        currentStreak: 0,
        previousLastPoop: DateTime(2026, 7, 5, 8, 0),
        newEventDate: DateTime(2026, 7, 5, 12, 0),
      );
      expect(streak, equals(1));
    });

    test('Evento al día siguiente incrementa la racha', () {
      // Caso del bug original: con Firebase real la racha nunca subía porque
      // se comparaba contra el lastPoop ya sobrescrito por el propio evento.
      final streak = KKEvent.calculateIncrementalStreak(
        currentStreak: 3,
        previousLastPoop: DateTime(2026, 7, 4, 23, 50),
        newEventDate: DateTime(2026, 7, 5, 0, 10),
      );
      expect(streak, equals(4));
    });

    test('Hueco de más de un día reinicia la racha en 1', () {
      final streak = KKEvent.calculateIncrementalStreak(
        currentStreak: 7,
        previousLastPoop: DateTime(2026, 7, 2, 10, 0),
        newEventDate: DateTime(2026, 7, 5, 10, 0),
      );
      expect(streak, equals(1));
    });

    test('Evento retro-fechado (anterior al último registro) reinicia en 1', () {
      final streak = KKEvent.calculateIncrementalStreak(
        currentStreak: 5,
        previousLastPoop: DateTime(2026, 7, 5, 10, 0),
        newEventDate: DateTime(2026, 7, 3, 10, 0),
      );
      expect(streak, equals(1));
    });

    test('Eventos en días consecutivos acumulan racha día a día', () {
      // Simula el flujo real de addEvent: cada día se calcula la racha
      // contra el lastPoop del día anterior y se actualiza el estado.
      int currentStreak = 0;
      DateTime? lastPoop;

      for (int day = 1; day <= 10; day++) {
        final eventDate = DateTime(2026, 7, day, 9, 0);
        currentStreak = KKEvent.calculateIncrementalStreak(
          currentStreak: currentStreak,
          previousLastPoop: lastPoop,
          newEventDate: eventDate,
        );
        lastPoop = eventDate;
        expect(currentStreak, equals(day));
      }

      // Un segundo evento el último día no debe alterar la racha
      final sameDayStreak = KKEvent.calculateIncrementalStreak(
        currentStreak: currentStreak,
        previousLastPoop: lastPoop,
        newEventDate: DateTime(2026, 7, 10, 21, 0),
      );
      expect(sameDayStreak, equals(10));
    });
  });
}
