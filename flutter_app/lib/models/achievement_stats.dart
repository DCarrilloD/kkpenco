import 'event.dart';

/// Contadores agregados por usuario para evaluar logros sin descargar la
/// colección `events` entera en cada guardado (mejora 2.1 de PLAN_MEJORAS.md).
///
/// Se persiste como el mapa `achStats` dentro del documento del usuario y se
/// actualiza de forma incremental con [fold] en el mismo `batch` del evento.
/// Es lógica PURA (sin dependencias de Firestore) para poder testearla directa,
/// igual que `KKEvent.calculateIncrementalStreak`.
///
/// Nota: se cuenta "desde ahora" (sin backfill del histórico). Los agregados
/// arrancan a cero; los logros ya desbloqueados viven aparte en `achievements`.
class AchievementStats {
  // Contadores simples
  int totalCount;
  int speedCount; // duración en (0, 60) s
  int longCount; // duración > 1500 s
  int natureCount; // ubicación == naturaleza
  int officeCount; // ubicación == trabajo
  int earlyCount; // hora en [5, 8)
  int nightCount; // hora en [0, 4)
  int festiveCount; // 25-dic o 1-ene
  int weekendCount; // sábado o domingo
  int outOfHomeCount; // ubicación != casa

  // Flags y pesos
  bool officeOvertime; // trabajo fuera de horario (hora >= 18 o < 8)
  double weightTotal; // gramos acumulados
  double maxSingleWeight; // peso máximo de un solo evento
  double? minSingleWeight; // peso mínimo de un solo evento (null hasta el 1º)
  int durationTotal; // segundos acumulados

  // Rachas de dificultad (eventos consecutivos con la misma dificultad)
  int easyRunCurrent; // dificultad == 1 seguidas
  int easyRunMax;
  int hardRunCurrent; // dificultad == 5 seguidas
  int hardRunMax;

  // Conjuntos de valores distintos
  final List<String> colors; // colores distintos vistos
  final List<String> consistencies; // consistencias distintas
  final List<String> coords; // "lat3_lon3" distintas (tope 30)

  // Mapas acotados
  final Map<String, int> hourCounts; // "0".."23" -> nº eventos
  final Map<String, int> monthCounts; // "YYYY-M" -> nº eventos
  final Map<String, int> workMonthCounts; // "YYYY-M" -> nº en trabajo

  // Alcance anual / diario
  int statsYear; // año al que corresponden yearCount/activeDaysThisYear
  int yearCount; // eventos en statsYear
  int activeDaysThisYear; // días distintos con evento en statsYear
  String todayKey; // "YYYY-M-D" del último día contado
  int todayCount; // eventos en todayKey
  int maxPoopsInADay; // máximo histórico de eventos en un mismo día
  String lastMonthKey; // "YYYY-M" del último evento

  static const int _coordsCap = 30; // ningún logro pide más coords distintas

  AchievementStats({
    this.totalCount = 0,
    this.speedCount = 0,
    this.longCount = 0,
    this.natureCount = 0,
    this.officeCount = 0,
    this.earlyCount = 0,
    this.nightCount = 0,
    this.festiveCount = 0,
    this.weekendCount = 0,
    this.outOfHomeCount = 0,
    this.officeOvertime = false,
    this.weightTotal = 0.0,
    this.maxSingleWeight = 0.0,
    this.minSingleWeight,
    this.durationTotal = 0,
    this.easyRunCurrent = 0,
    this.easyRunMax = 0,
    this.hardRunCurrent = 0,
    this.hardRunMax = 0,
    List<String>? colors,
    List<String>? consistencies,
    List<String>? coords,
    Map<String, int>? hourCounts,
    Map<String, int>? monthCounts,
    Map<String, int>? workMonthCounts,
    this.statsYear = 0,
    this.yearCount = 0,
    this.activeDaysThisYear = 0,
    this.todayKey = '',
    this.todayCount = 0,
    this.maxPoopsInADay = 0,
    this.lastMonthKey = '',
  })  : colors = colors ?? [],
        consistencies = consistencies ?? [],
        coords = coords ?? [],
        hourCounts = hourCounts ?? {},
        monthCounts = monthCounts ?? {},
        workMonthCounts = workMonthCounts ?? {};

  factory AchievementStats.fromMap(Map<String, dynamic>? map) {
    if (map == null) return AchievementStats();
    int i(String k) => (map[k] as num?)?.toInt() ?? 0;
    double d(String k) => (map[k] as num?)?.toDouble() ?? 0.0;
    List<String> l(String k) =>
        (map[k] as List?)?.map((e) => e.toString()).toList() ?? [];
    Map<String, int> m(String k) => ((map[k] as Map?) ?? {})
        .map((key, value) => MapEntry(key.toString(), (value as num).toInt()));

    return AchievementStats(
      totalCount: i('totalCount'),
      speedCount: i('speedCount'),
      longCount: i('longCount'),
      natureCount: i('natureCount'),
      officeCount: i('officeCount'),
      earlyCount: i('earlyCount'),
      nightCount: i('nightCount'),
      festiveCount: i('festiveCount'),
      weekendCount: i('weekendCount'),
      outOfHomeCount: i('outOfHomeCount'),
      officeOvertime: map['officeOvertime'] as bool? ?? false,
      weightTotal: d('weightTotal'),
      maxSingleWeight: d('maxSingleWeight'),
      minSingleWeight: (map['minSingleWeight'] as num?)?.toDouble(),
      durationTotal: i('durationTotal'),
      easyRunCurrent: i('easyRunCurrent'),
      easyRunMax: i('easyRunMax'),
      hardRunCurrent: i('hardRunCurrent'),
      hardRunMax: i('hardRunMax'),
      colors: l('colors'),
      consistencies: l('consistencies'),
      coords: l('coords'),
      hourCounts: m('hourCounts'),
      monthCounts: m('monthCounts'),
      workMonthCounts: m('workMonthCounts'),
      statsYear: i('statsYear'),
      yearCount: i('yearCount'),
      activeDaysThisYear: i('activeDaysThisYear'),
      todayKey: map['todayKey'] as String? ?? '',
      todayCount: i('todayCount'),
      maxPoopsInADay: i('maxPoopsInADay'),
      lastMonthKey: map['lastMonthKey'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalCount': totalCount,
      'speedCount': speedCount,
      'longCount': longCount,
      'natureCount': natureCount,
      'officeCount': officeCount,
      'earlyCount': earlyCount,
      'nightCount': nightCount,
      'festiveCount': festiveCount,
      'weekendCount': weekendCount,
      'outOfHomeCount': outOfHomeCount,
      'officeOvertime': officeOvertime,
      'weightTotal': weightTotal,
      'maxSingleWeight': maxSingleWeight,
      'minSingleWeight': minSingleWeight,
      'durationTotal': durationTotal,
      'easyRunCurrent': easyRunCurrent,
      'easyRunMax': easyRunMax,
      'hardRunCurrent': hardRunCurrent,
      'hardRunMax': hardRunMax,
      'colors': colors,
      'consistencies': consistencies,
      'coords': coords,
      'hourCounts': hourCounts,
      'monthCounts': monthCounts,
      'workMonthCounts': workMonthCounts,
      'statsYear': statsYear,
      'yearCount': yearCount,
      'activeDaysThisYear': activeDaysThisYear,
      'todayKey': todayKey,
      'todayCount': todayCount,
      'maxPoopsInADay': maxPoopsInADay,
      'lastMonthKey': lastMonthKey,
    };
  }

  /// Aplica UN evento a los contadores de forma incremental y devuelve `this`
  /// (muta en sitio; el llamador ya trabaja con una instancia recién leída).
  AchievementStats fold(KKEvent event) {
    final ts = event.timestamp;
    final year = ts.year;
    final month = ts.month;
    final day = ts.day;
    final hour = ts.hour;
    final dayKey = '$year-$month-$day';
    final monthKey = '$year-$month';

    // Alcance anual: al cambiar de año se reinician los contadores anuales.
    if (year != statsYear) {
      statsYear = year;
      yearCount = 0;
      activeDaysThisYear = 0;
    }

    totalCount++;
    yearCount++;

    // Duración
    final dur = event.duration;
    if (dur != null && dur > 0 && dur < 60) speedCount++;
    if (dur != null && dur > 1500) longCount++;
    durationTotal += dur ?? 0;

    // Ubicación
    if (event.location == LocationTag.naturaleza) natureCount++;
    if (event.location == LocationTag.trabajo) {
      officeCount++;
      workMonthCounts[monthKey] = (workMonthCounts[monthKey] ?? 0) + 1;
      if (hour >= 18 || hour < 8) officeOvertime = true;
    }
    if (event.location != LocationTag.casa) outOfHomeCount++;

    // Franja horaria
    if (hour >= 5 && hour < 8) earlyCount++;
    if (hour >= 0 && hour < 4) nightCount++;
    final hk = hour.toString();
    hourCounts[hk] = (hourCounts[hk] ?? 0) + 1;

    // Fechas especiales
    if ((month == 12 && day == 25) || (month == 1 && day == 1)) festiveCount++;

    // Fin de semana
    if (ts.weekday == DateTime.saturday || ts.weekday == DateTime.sunday) {
      weekendCount++;
    }

    // Peso
    final w = event.estimatedWeight;
    weightTotal += w;
    if (w > maxSingleWeight) maxSingleWeight = w;
    if (minSingleWeight == null || w < minSingleWeight!) minSingleWeight = w;

    // Rachas de dificultad
    if (event.difficulty == 1) {
      easyRunCurrent++;
      if (easyRunCurrent > easyRunMax) easyRunMax = easyRunCurrent;
      hardRunCurrent = 0;
    } else if (event.difficulty == 5) {
      hardRunCurrent++;
      if (hardRunCurrent > hardRunMax) hardRunMax = hardRunCurrent;
      easyRunCurrent = 0;
    } else {
      easyRunCurrent = 0;
      hardRunCurrent = 0;
    }

    // Valores distintos
    final colorName = event.color.displayName;
    if (!colors.contains(colorName)) colors.add(colorName);
    final consName = event.consistency.displayName;
    if (!consistencies.contains(consName)) consistencies.add(consName);
    if (event.latitude != null && event.longitude != null) {
      final coordKey =
          '${event.latitude!.toStringAsFixed(3)}_${event.longitude!.toStringAsFixed(3)}';
      if (coords.length < _coordsCap && !coords.contains(coordKey)) {
        coords.add(coordKey);
      }
    }

    // Totales mensuales
    monthCounts[monthKey] = (monthCounts[monthKey] ?? 0) + 1;
    lastMonthKey = monthKey;

    // Día: eventos por día y días activos del año
    if (dayKey == todayKey) {
      todayCount++;
    } else {
      todayKey = dayKey;
      todayCount = 1;
      activeDaysThisYear++;
    }
    if (todayCount > maxPoopsInADay) maxPoopsInADay = todayCount;

    return this;
  }
}

/// Estación (hemisferio norte) a la que pertenece un mes.
String _seasonOf(int month) {
  if (month >= 3 && month <= 5) return 'primavera';
  if (month >= 6 && month <= 8) return 'verano';
  if (month >= 9 && month <= 11) return 'otono';
  return 'invierno';
}

/// Devuelve los IDs de logros cuyo umbral se cumple según [stats] (más rachas,
/// duelos y kcoins ya conocidos por el llamador) y que NO estén ya en
/// [existing]. Es pura: no lee ni escribe nada.
List<String> evaluateUnlockedAchievements({
  required List<String> existing,
  required AchievementStats stats,
  required int currentStreak,
  required int maxStreak,
  required int duelsCompleted,
  required int kcoins,
}) {
  final result = <String>[];
  void check(String id, bool condition) {
    if (condition && !existing.contains(id) && !result.contains(id)) {
      result.add(id);
    }
  }

  // Meses/estaciones del año en curso (para logros anuales)
  final monthsThisYear = <int>{};
  for (final key in stats.monthCounts.keys) {
    final parts = key.split('-');
    if (parts.length == 2 && int.tryParse(parts[0]) == stats.statsYear) {
      final m = int.tryParse(parts[1]);
      if (m != null) monthsThisYear.add(m);
    }
  }
  final seasons = monthsThisYear.map(_seasonOf).toSet();

  // Evento único (contador >= 1)
  check('first_poop', stats.totalCount >= 1);
  check('speedrunner', stats.speedCount >= 1);
  check('meditator', stats.longCount >= 1);
  check('colossus', stats.maxSingleWeight > 500);
  check('feather', stats.minSingleWeight != null && stats.minSingleWeight! < 80);
  check('forest', stats.natureCount >= 1);
  check('office', stats.officeCount >= 1);
  check('early_bird', stats.earlyCount >= 1);
  check('night_owl', stats.nightCount >= 1);
  check('festive', stats.festiveCount >= 1);
  check('office_overtime', stats.officeOvertime);

  // Acumulativos
  check('speed_demon', stats.speedCount >= 5);
  check('marathoner', stats.longCount >= 10);
  check('green_peace', stats.natureCount >= 5);
  check('night_stalker', stats.nightCount >= 10);
  check('weekend_warrior', stats.weekendCount >= 15);
  check('out_of_home_50', stats.outOfHomeCount >= 50);
  check('weight_champion', stats.weightTotal >= 5000.0);
  check('heavy_weight_20kg', stats.weightTotal >= 20000.0);
  check('weight_titan_100kg', stats.weightTotal >= 100000.0);
  check('time_marathoner_10h', stats.durationTotal >= 36000);
  check('perfect_attendance', stats.easyRunMax >= 5);
  check('hard_worker', stats.hardRunMax >= 5);
  check('poop_rainbow', stats.colors.length >= 5);
  check('poop_variety', stats.consistencies.length >= 3);
  check('all_day_active', stats.hourCounts.length >= 12);
  check('regularity_expert_100', stats.hourCounts.values.any((v) => v >= 100));
  check('explorer', stats.coords.length >= 3);
  check('gps_mapper', stats.coords.length >= 10);
  check('gps_nomad_30', stats.coords.length >= 30);
  check('double_drop', stats.maxPoopsInADay >= 2);
  check('triple_drop', stats.maxPoopsInADay >= 3);

  // Mensuales (mes del último evento)
  check('worker_of_the_month',
      (stats.workMonthCounts[stats.lastMonthKey] ?? 0) >= 20);
  check('monthly_poop_50', (stats.monthCounts[stats.lastMonthKey] ?? 0) >= 50);

  // Anuales
  check('monthly_consistency_12', monthsThisYear.length >= 12);
  check('four_seasons', seasons.length >= 4);
  check('year_active_days_100', stats.activeDaysThisYear >= 100);
  check('year_poop_100', stats.yearCount >= 100);
  check('year_poop_200', stats.yearCount >= 200);
  check('year_poop_300', stats.yearCount >= 300);
  check('year_poop_400', stats.yearCount >= 400);

  // Rachas diarias (ya calculadas en addEvent)
  check('streak_3', currentStreak >= 3 || maxStreak >= 3);
  check('streak_7', currentStreak >= 7 || maxStreak >= 7);
  check('streak_15', currentStreak >= 15 || maxStreak >= 15);
  check('streak_30', currentStreak >= 30 || maxStreak >= 30);
  check('streak_50', currentStreak >= 50 || maxStreak >= 50);

  // Duelos y economía
  check('duel_master', duelsCompleted >= 5);
  check('caca_capitalist', kcoins >= 500);

  return result;
}
