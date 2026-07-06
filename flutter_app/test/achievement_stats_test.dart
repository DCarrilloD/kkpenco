import 'package:flutter_test/flutter_test.dart';
import 'package:kkpenco/models/event.dart';
import 'package:kkpenco/models/achievement_stats.dart';

// Constructor de eventos de prueba con valores por defecto razonables.
KKEvent ev({
  required DateTime ts,
  int? duration,
  Consistency consistency = Consistency.normal,
  PoopColor color = PoopColor.cafe,
  LocationTag location = LocationTag.casa,
  int difficulty = 3,
  double weight = 300,
  double? lat,
  double? lon,
}) {
  return KKEvent(
    id: 'e',
    userId: 'u',
    timestamp: ts,
    duration: duration,
    consistency: consistency,
    color: color,
    location: location,
    difficulty: difficulty,
    estimatedWeight: weight,
    latitude: lat,
    longitude: lon,
  );
}

List<String> unlocked(
  AchievementStats stats, {
  List<String> existing = const [],
  int currentStreak = 0,
  int maxStreak = 0,
  int duelsCompleted = 0,
  int kcoins = 0,
}) {
  return evaluateUnlockedAchievements(
    existing: existing,
    stats: stats,
    currentStreak: currentStreak,
    maxStreak: maxStreak,
    duelsCompleted: duelsCompleted,
    kcoins: kcoins,
  );
}

void main() {
  group('AchievementStats.fold — acumulación incremental', () {
    test('Un evento inicia el contador y habilita first_poop', () {
      final s = AchievementStats().fold(ev(ts: DateTime(2026, 7, 6, 10)));
      expect(s.totalCount, 1);
      expect(s.yearCount, 1);
      expect(s.statsYear, 2026);
      expect(unlocked(s), contains('first_poop'));
    });

    test('Peso total acumula y dispara weight_champion en 5 kg', () {
      var s = AchievementStats();
      for (var i = 0; i < 16; i++) {
        s = s.fold(ev(ts: DateTime(2026, 7, 6, 10), weight: 320));
      }
      expect(s.weightTotal, closeTo(5120, 0.001));
      expect(unlocked(s), contains('weight_champion'));
    });

    test('colossus por peso máximo y feather por peso mínimo', () {
      var s = AchievementStats().fold(ev(ts: DateTime(2026, 7, 6, 10), weight: 600));
      expect(unlocked(s), contains('colossus'));
      expect(unlocked(s), isNot(contains('feather')));
      s = s.fold(ev(ts: DateTime(2026, 7, 6, 11), weight: 60));
      expect(unlocked(s), contains('feather'));
    });

    test('Cacas nocturnas: night_owl a 1 y night_stalker a 10', () {
      var s = AchievementStats();
      s = s.fold(ev(ts: DateTime(2026, 7, 6, 2)));
      expect(s.nightCount, 1);
      expect(unlocked(s), contains('night_owl'));
      expect(unlocked(s), isNot(contains('night_stalker')));
      for (var i = 0; i < 9; i++) {
        s = s.fold(ev(ts: DateTime(2026, 7, 6, 3)));
      }
      expect(s.nightCount, 10);
      expect(unlocked(s), contains('night_stalker'));
    });

    test('Coordenadas distintas: explorer, gps_mapper y tope en 30', () {
      var s = AchievementStats();
      for (var i = 0; i < 40; i++) {
        s = s.fold(ev(
          ts: DateTime(2026, 7, 6, 10),
          lat: 40.0 + i / 1000.0,
          lon: -3.0 - i / 1000.0,
        ));
      }
      // Se corta en 30 aunque haya 40 coordenadas distintas.
      expect(s.coords.length, 30);
      final u = unlocked(s);
      expect(u, containsAll(['explorer', 'gps_mapper', 'gps_nomad_30']));
    });

    test('Coordenadas repetidas no cuentan como distintas', () {
      var s = AchievementStats();
      for (var i = 0; i < 5; i++) {
        s = s.fold(ev(ts: DateTime(2026, 7, 6, 10), lat: 40.123, lon: -3.456));
      }
      expect(s.coords.length, 1);
      expect(unlocked(s), isNot(contains('explorer')));
    });

    test('perfect_attendance: 5 dificultad 1 seguidas; un corte reinicia', () {
      var s = AchievementStats();
      for (var i = 0; i < 4; i++) {
        s = s.fold(ev(ts: DateTime(2026, 7, 6, 10), difficulty: 1));
      }
      s = s.fold(ev(ts: DateTime(2026, 7, 6, 11), difficulty: 3)); // corte
      for (var i = 0; i < 4; i++) {
        s = s.fold(ev(ts: DateTime(2026, 7, 6, 12), difficulty: 1));
      }
      expect(unlocked(s), isNot(contains('perfect_attendance')));
      s = s.fold(ev(ts: DateTime(2026, 7, 6, 13), difficulty: 1)); // 5ª seguida
      expect(s.easyRunMax, 5);
      expect(unlocked(s), contains('perfect_attendance'));
    });

    test('hard_worker: 5 dificultad 5 seguidas', () {
      var s = AchievementStats();
      for (var i = 0; i < 5; i++) {
        s = s.fold(ev(ts: DateTime(2026, 7, 6, 10), difficulty: 5));
      }
      expect(s.hardRunMax, 5);
      expect(unlocked(s), contains('hard_worker'));
    });

    test('maxPoopsInADay: double_drop y triple_drop en el mismo día', () {
      var s = AchievementStats();
      s = s.fold(ev(ts: DateTime(2026, 7, 6, 8)));
      expect(unlocked(s), isNot(contains('double_drop')));
      s = s.fold(ev(ts: DateTime(2026, 7, 6, 12)));
      expect(s.maxPoopsInADay, 2);
      expect(unlocked(s), contains('double_drop'));
      s = s.fold(ev(ts: DateTime(2026, 7, 6, 20)));
      expect(s.maxPoopsInADay, 3);
      expect(unlocked(s), contains('triple_drop'));
      // Un evento al día siguiente no baja el máximo histórico.
      s = s.fold(ev(ts: DateTime(2026, 7, 7, 9)));
      expect(s.maxPoopsInADay, 3);
      expect(s.todayCount, 1);
    });

    test('Días activos del año cuentan días distintos, no eventos', () {
      var s = AchievementStats();
      s = s.fold(ev(ts: DateTime(2026, 3, 1, 9)));
      s = s.fold(ev(ts: DateTime(2026, 3, 1, 20))); // mismo día
      s = s.fold(ev(ts: DateTime(2026, 3, 2, 9)));
      expect(s.activeDaysThisYear, 2);
    });

    test('Cambio de año reinicia yearCount y días activos', () {
      var s = AchievementStats();
      s = s.fold(ev(ts: DateTime(2025, 12, 31, 23)));
      expect(s.yearCount, 1);
      s = s.fold(ev(ts: DateTime(2026, 1, 1, 0)));
      expect(s.statsYear, 2026);
      expect(s.yearCount, 1);
      expect(s.activeDaysThisYear, 1);
      // El peso total NO se reinicia (es de por vida).
      expect(s.weightTotal, closeTo(600, 0.001));
    });

    test('four_seasons y monthly_consistency_12 usan los meses del año', () {
      var s = AchievementStats();
      // Un evento en cada mes de 2026 -> 12 meses, 4 estaciones.
      for (var m = 1; m <= 12; m++) {
        s = s.fold(ev(ts: DateTime(2026, m, 5, 10)));
      }
      final u = unlocked(s);
      expect(u, contains('four_seasons'));
      expect(u, contains('monthly_consistency_12'));
    });

    test('worker_of_the_month: 20 en trabajo el mismo mes', () {
      var s = AchievementStats();
      for (var i = 0; i < 20; i++) {
        s = s.fold(ev(
          ts: DateTime(2026, 7, (i % 28) + 1, 10),
          location: LocationTag.trabajo,
        ));
      }
      expect(s.workMonthCounts['2026-7'], 20);
      expect(unlocked(s), contains('worker_of_the_month'));
    });
  });

  group('evaluateUnlockedAchievements — filtrado y "contar desde ahora"', () {
    test('No re-desbloquea logros ya presentes en existing', () {
      final s = AchievementStats().fold(ev(ts: DateTime(2026, 7, 6, 6)));
      // first_poop y early_bird corresponderían, pero ya están desbloqueados.
      final u = unlocked(s, existing: ['first_poop', 'early_bird']);
      expect(u, isNot(contains('first_poop')));
      expect(u, isNot(contains('early_bird')));
    });

    test('Agregados vacíos no disparan logros de umbral alto', () {
      final u = unlocked(AchievementStats());
      expect(u, isEmpty);
    });

    test('Rachas, duelos y kcoins se evalúan con los valores externos', () {
      final s = AchievementStats().fold(ev(ts: DateTime(2026, 7, 6, 10)));
      final u = unlocked(s,
          currentStreak: 7, maxStreak: 7, duelsCompleted: 5, kcoins: 500);
      expect(u, containsAll(['streak_3', 'streak_7', 'duel_master', 'caca_capitalist']));
      expect(u, isNot(contains('streak_15')));
    });
  });

  group('AchievementStats serialización', () {
    test('toMap/fromMap conserva el estado', () {
      var s = AchievementStats();
      s = s.fold(ev(ts: DateTime(2026, 7, 6, 2), weight: 600, difficulty: 5, lat: 1.0, lon: 2.0));
      s = s.fold(ev(ts: DateTime(2026, 7, 7, 10), weight: 60, difficulty: 5));
      final restored = AchievementStats.fromMap(s.toMap());
      expect(restored.totalCount, s.totalCount);
      expect(restored.weightTotal, s.weightTotal);
      expect(restored.maxSingleWeight, s.maxSingleWeight);
      expect(restored.minSingleWeight, s.minSingleWeight);
      expect(restored.hardRunMax, s.hardRunMax);
      expect(restored.coords, s.coords);
      expect(restored.monthCounts, s.monthCounts);
      expect(restored.activeDaysThisYear, s.activeDaysThisYear);
      expect(restored.maxPoopsInADay, s.maxPoopsInADay);
    });
  });
}
