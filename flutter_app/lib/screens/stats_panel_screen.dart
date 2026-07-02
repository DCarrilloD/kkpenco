import 'dart:io';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../services/database_service.dart';
import '../widgets/shimmer_loading.dart';

class StatsPanelScreen extends StatefulWidget {
  const StatsPanelScreen({super.key});

  @override
  State<StatsPanelScreen> createState() => _StatsPanelScreenState();
}

class _StatsPanelScreenState extends State<StatsPanelScreen> {
  final DatabaseService _dbService = DatabaseService();
  bool _isLoading = true;
  String? _errorMessage;
  List<KKEvent> _allEvents = [];
  Map<String, String> _userNamesMap = {}; // userId -> display name
  String? _selectedUserId; // Para la vista detallada de usuario

  // Variables de filtrado por año
  String _selectedYear = 'Todos';
  List<String> _availableYears = [];

  // Variables memorizadas para evitar recálculos en el build
  double _totalWeightGrams = 0.0;
  double _totalWeightKg = 0.0;
  double _avgWeight = 0.0;
  Map<Consistency, int> _consistencyDistribution = {};
  Map<String, double> _poopsWeightByUser = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Getters para datos filtrados dinámicamente
  List<KKEvent> get _filteredEvents {
    if (_selectedYear == 'Todos') {
      return _allEvents;
    }
    final targetYear = int.tryParse(_selectedYear);
    if (targetYear == null) return _allEvents;
    return _allEvents.where((e) => e.timestamp.year == targetYear).toList();
  }

  Map<String, List<KKEvent>> get _filteredUserEventsMap {
    final Map<String, List<KKEvent>> map = {};
    for (var event in _filteredEvents) {
      final userId = event.userId;
      map.putIfAbsent(userId, () => []).add(event);
    }
    return map;
  }

  void _calculateDerivedStats() {
    final events = _filteredEvents;
    _totalWeightGrams = events.fold(0.0, (sum, e) => sum + e.estimatedWeight);
    _totalWeightKg = _totalWeightGrams / 1000.0;
    _avgWeight = events.isEmpty ? 0.0 : _totalWeightGrams / events.length;

    // Distribución de consistencia
    final Map<Consistency, int> consistencyDistribution = {};
    for (var e in events) {
      consistencyDistribution[e.consistency] = (consistencyDistribution[e.consistency] ?? 0) + 1;
    }
    _consistencyDistribution = consistencyDistribution;

    // Rankings de usuarios
    final Map<String, double> poopsWeightByUser = {};
    for (var e in events) {
      poopsWeightByUser[e.userId] = (poopsWeightByUser[e.userId] ?? 0.0) + e.estimatedWeight;
    }
    _poopsWeightByUser = poopsWeightByUser;
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final events = await _dbService.getAllEvents();
      
      // Determinar los años disponibles en los registros
      final Set<String> yearsSet = {};
      for (var e in events) {
        yearsSet.add(e.timestamp.year.toString());
      }
      final List<String> years = yearsSet.toList()..sort((a, b) => b.compareTo(a));

      final Map<String, String> userNamesMap = {};
      for (var event in events) {
        final userId = event.userId;
        userNamesMap[userId] = event.displayName ?? 'Usuario Desconocido';
      }

      setState(() {
        _allEvents = events;
        _availableYears = ['Todos', ...years];
        _userNamesMap = userNamesMap;

        // Seleccionar año actual si existe en los datos, de lo contrario 'Todos'
        final currentYearStr = DateTime.now().year.toString();
        if (years.contains(currentYearStr)) {
          _selectedYear = currentYearStr;
        } else {
          _selectedYear = 'Todos';
        }

        // Seleccionar el primer usuario si hay
        final filteredMap = _filteredUserEventsMap;
        if (filteredMap.isNotEmpty) {
          _selectedUserId = filteredMap.keys.first;
        }

        _calculateDerivedStats();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar las estadísticas: $e';
        _isLoading = false;
      });
    }
  }

  void _onYearChanged(String? newYear) {
    if (newYear == null) return;
    setState(() {
      _selectedYear = newYear;
      final filteredMap = _filteredUserEventsMap;
      if (filteredMap.isNotEmpty) {
        if (!filteredMap.containsKey(_selectedUserId)) {
          _selectedUserId = filteredMap.keys.first;
        }
      } else {
        _selectedUserId = null;
      }
      _calculateDerivedStats();
    });
  }

  // Calcula estadísticas generales para una lista de eventos
  Map<String, dynamic> _calculateStats(List<KKEvent> events) {
    if (events.isEmpty) {
      return {
        'total': 0,
        'totalWeight': 0.0,
        'avgWeight': 0.0,
        'avgDifficulty': 0.0,
        'weeklyAvg': 0.0,
        'favConsistency': 'N/A',
        'favLocation': 'N/A',
        'favColor': 'N/A',
        'avgDuration': 0.0,
      };
    }

    final total = events.length;
    double totalWeight = 0.0;
    double totalDifficulty = 0.0;
    double totalDuration = 0.0;
    int durationCount = 0;

    final Map<Consistency, int> consistencyCounts = {};
    final Map<LocationTag, int> locationCounts = {};
    final Map<PoopColor, int> colorCounts = {};

    for (var e in events) {
      totalWeight += e.estimatedWeight;
      totalDifficulty += e.difficulty;
      if (e.duration != null) {
        totalDuration += e.duration!;
        durationCount++;
      }

      consistencyCounts[e.consistency] = (consistencyCounts[e.consistency] ?? 0) + 1;
      locationCounts[e.location] = (locationCounts[e.location] ?? 0) + 1;
      colorCounts[e.color] = (colorCounts[e.color] ?? 0) + 1;
    }

    // Promedio semanal
    final dates = events.map((e) => e.timestamp).toList()..sort();
    final firstDate = dates.first;
    final lastDate = dates.last;
    final diffDays = lastDate.difference(firstDate).inDays;
    final weeks = diffDays < 7 ? 1.0 : diffDays / 7.0;
    final weeklyAvg = total / weeks;

    // Favoritos
    final favConsistency = consistencyCounts.isEmpty
        ? 'N/A'
        : consistencyCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key.displayName;
    final favLocation = locationCounts.isEmpty
        ? 'N/A'
        : locationCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key.displayName;
    final favColor = colorCounts.isEmpty
        ? 'N/A'
        : colorCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key.displayName;

    return {
      'total': total,
      'totalWeight': totalWeight,
      'avgWeight': totalWeight / total,
      'avgDifficulty': totalDifficulty / total,
      'weeklyAvg': weeklyAvg,
      'favConsistency': favConsistency,
      'favLocation': favLocation,
      'favColor': favColor,
      'avgDuration': durationCount == 0 ? 0.0 : totalDuration / durationCount,
    };
  }

  // Calcula patrones de comportamiento temporal
  Map<String, dynamic> _calculateTemporalPatterns(List<KKEvent> events) {
    if (events.isEmpty) {
      return {
        'weekdays': <int, int>{},
        'hourly': <String, int>{},
        'mostProductiveDay': 'N/A',
        'mostProductiveHour': 'N/A',
      };
    }

    final Map<int, int> weekdaysCount = {};
    final Map<String, int> hourlyCount = {
      'Madrugada (00-06)': 0,
      'Mañana (06-12)': 0,
      'Tarde (12-18)': 0,
      'Noche (18-24)': 0,
    };

    for (var e in events) {
      final wday = e.timestamp.weekday;
      weekdaysCount[wday] = (weekdaysCount[wday] ?? 0) + 1;

      final hour = e.timestamp.hour;
      if (hour >= 0 && hour < 6) {
        hourlyCount['Madrugada (00-06)'] = hourlyCount['Madrugada (00-06)']! + 1;
      } else if (hour >= 6 && hour < 12) {
        hourlyCount['Mañana (06-12)'] = hourlyCount['Mañana (06-12)']! + 1;
      } else if (hour >= 12 && hour < 18) {
        hourlyCount['Tarde (12-18)'] = hourlyCount['Tarde (12-18)']! + 1;
      } else {
        hourlyCount['Noche (18-24)'] = hourlyCount['Noche (18-24)']! + 1;
      }
    }

    final weekdayNames = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    int maxDayCount = -1;
    int productiveDayIndex = 1;
    weekdaysCount.forEach((day, count) {
      if (count > maxDayCount) {
        maxDayCount = count;
        productiveDayIndex = day;
      }
    });
    final mostProductiveDay = maxDayCount > 0
        ? '${weekdayNames[productiveDayIndex - 1]} ($maxDayCount)'
        : 'N/A';

    String mostProductiveHour = 'N/A';
    int maxHourCount = -1;
    hourlyCount.forEach((franja, count) {
      if (count > maxHourCount) {
        maxHourCount = count;
        mostProductiveHour = '$franja ($count)';
      }
    });

    return {
      'weekdays': weekdaysCount,
      'hourly': hourlyCount,
      'mostProductiveDay': mostProductiveDay,
      'mostProductiveHour': mostProductiveHour,
    };
  }

  // Calcula los récords y premios del periodo seleccionado
  Map<String, dynamic> _calculateAnnualRecords(List<KKEvent> events) {
    if (events.isEmpty) return {};

    KKEvent? heaviest;
    KKEvent? longest;
    KKEvent? shortest;
    KKEvent? earliest; // Madrugador
    KKEvent? latest;   // Noctámbulo

    int minEarliestMinutes = 24 * 60; // 5:00 - 11:59
    int maxLatestMinutes = -1;       // 22:00 - 04:59

    for (var e in events) {
      // 1. Más pesada
      if (heaviest == null || e.estimatedWeight > heaviest.estimatedWeight) {
        heaviest = e;
      }
      // 2. Más larga
      if (e.duration != null) {
        if (longest == null || e.duration! > longest.duration!) {
          longest = e;
        }
        if (e.duration! > 0) {
          if (shortest == null || e.duration! < shortest.duration!) {
            shortest = e;
          }
        }
      }

      // 3. Madrugador (rango 05:00 a 11:59)
      final minutes = e.timestamp.hour * 60 + e.timestamp.minute;
      if (e.timestamp.hour >= 5 && e.timestamp.hour < 12) {
        if (minutes < minEarliestMinutes) {
          minEarliestMinutes = minutes;
          earliest = e;
        }
      }

      // 4. Noctámbulo (rango 22:00 a 04:59)
      int noctMinutes = minutes;
      if (e.timestamp.hour < 5) {
        noctMinutes += 24 * 60;
      }
      if (e.timestamp.hour >= 22 || e.timestamp.hour < 5) {
        if (noctMinutes > maxLatestMinutes) {
          maxLatestMinutes = noctMinutes;
          latest = e;
        }
      }
    }

    // 5. Racha más larga
    String streakUser = 'N/A';
    int maxStreak = 0;
    
    final Map<String, List<KKEvent>> localMap = {};
    for (var e in events) {
      localMap.putIfAbsent(e.userId, () => []).add(e);
    }
    localMap.forEach((userId, userEvs) {
      final streak = KKEvent.calculateStreak(userEvs);
      if (streak > maxStreak) {
        maxStreak = streak;
        streakUser = userEvs.first.displayName ?? _userNamesMap[userId] ?? 'Usuario';
      }
    });

    return {
      'heaviest': heaviest,
      'longest': longest,
      'shortest': shortest,
      'earliest': earliest,
      'latest': latest,
      'streakUser': streakUser,
      'maxStreak': maxStreak,
    };
  }

  Future<void> _exportToExcel() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final excel = Excel.createExcel();

      // Configure sheets
      const String sheet1Name = 'Resumen General';
      const String sheet2Name = 'Clasificación y Rendimiento';
      const String sheet3Name = 'Récords y Premios';
      const String sheet4Name = 'Análisis de Patrones';
      const String sheet5Name = 'Histórico Detallado';

      excel.rename('Sheet1', sheet1Name);
      final Sheet sheetResumen = excel[sheet1Name];
      final Sheet sheetClasificacion = excel[sheet2Name];
      final Sheet sheetRecords = excel[sheet3Name];
      final Sheet sheetPatrones = excel[sheet4Name];
      final Sheet sheetHistorico = excel[sheet5Name];

      final CellStyle headerStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        fontFamily: getFontFamily(FontFamily.Calibri),
      );

      final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
      final dateOnlyFormat = DateFormat('yyyy-MM-dd');
      final timeOnlyFormat = DateFormat('HH:mm:ss');

      // --- HOJA 1: RESUMEN GENERAL ---
      sheetResumen.cell(CellIndex.indexByString("A1")).value = TextCellValue("Resumen de Estadísticas Anuales - Año: $_selectedYear 💩");
      sheetResumen.cell(CellIndex.indexByString("A1")).cellStyle = CellStyle(bold: true, fontSize: 14);

      sheetResumen.cell(CellIndex.indexByString("A3")).value = TextCellValue("Métrica");
      sheetResumen.cell(CellIndex.indexByString("A3")).cellStyle = headerStyle;
      sheetResumen.cell(CellIndex.indexByString("B3")).value = TextCellValue("Valor");
      sheetResumen.cell(CellIndex.indexByString("B3")).cellStyle = headerStyle;

      final double totalWeightGrams = _filteredEvents.fold(0.0, (sum, e) => sum + e.estimatedWeight);
      final double totalWeightKg = totalWeightGrams / 1000.0;
      final double avgWeight = _filteredEvents.isEmpty ? 0.0 : totalWeightGrams / _filteredEvents.length;
      final double totalDurationSecs = _filteredEvents.fold(0.0, (sum, e) => sum + (e.duration ?? 0));
      final double totalDurationHours = totalDurationSecs / 3600.0;

      final summaryData = [
        ["Año Seleccionado", _selectedYear],
        ["Total Registros del Grupo", "${_filteredEvents.length} deposiciones"],
        ["Peso Total Acumulado", "${totalWeightKg.toStringAsFixed(2)} kg"],
        ["Peso Promedio por Caca", "${avgWeight.toStringAsFixed(1)} g"],
        ["Tiempo Total en el Trono", "${totalDurationHours.toStringAsFixed(1)} horas"],
      ];

      for (int i = 0; i < summaryData.length; i++) {
        sheetResumen.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3 + i)).value = TextCellValue(summaryData[i][0]);
        sheetResumen.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 3 + i)).value = TextCellValue(summaryData[i][1]);
      }

      // --- HOJA 2: CLASIFICACIÓN Y RENDIMIENTO ---
      final clasHeaders = [
        "Puesto",
        "Nombre Usuario",
        "Total Cacas",
        "Peso Total (kg)",
        "Peso Promedio (g)",
        "Dificultad Promedio",
        "Duración Promedio (min)",
        "Racha Máxima (días)",
        "Consistencia Favorita",
        "Lugar Favorito",
        "Color Favorito"
      ];

      for (var col = 0; col < clasHeaders.length; col++) {
        final cell = sheetClasificacion.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
        cell.value = TextCellValue(clasHeaders[col]);
        cell.cellStyle = headerStyle;
      }

      final List<MapEntry<String, List<KKEvent>>> sortedUsers = _filteredUserEventsMap.entries.toList()
        ..sort((a, b) => b.value.length.compareTo(a.value.length));

      int clasRowIndex = 1;
      for (int i = 0; i < sortedUsers.length; i++) {
        final entry = sortedUsers[i];
        final userId = entry.key;
        final events = entry.value;
        final username = _userNamesMap[userId] ?? 'Usuario';
        final stats = _calculateStats(events);
        final streak = KKEvent.calculateStreak(events);

        sheetClasificacion.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: clasRowIndex)).value = IntCellValue(i + 1);
        sheetClasificacion.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: clasRowIndex)).value = TextCellValue(username);
        sheetClasificacion.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: clasRowIndex)).value = IntCellValue(stats['total']);
        sheetClasificacion.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: clasRowIndex)).value = DoubleCellValue(double.parse((stats['totalWeight'] / 1000.0).toStringAsFixed(2)));
        sheetClasificacion.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: clasRowIndex)).value = DoubleCellValue(double.parse((stats['avgWeight'] as double).toStringAsFixed(1)));
        sheetClasificacion.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: clasRowIndex)).value = DoubleCellValue(double.parse((stats['avgDifficulty'] as double).toStringAsFixed(1)));
        sheetClasificacion.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: clasRowIndex)).value = DoubleCellValue(double.parse(((stats['avgDuration'] as double) / 60.0).toStringAsFixed(1)));
        sheetClasificacion.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: clasRowIndex)).value = IntCellValue(streak);
        sheetClasificacion.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: clasRowIndex)).value = TextCellValue(stats['favConsistency']);
        sheetClasificacion.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: clasRowIndex)).value = TextCellValue(stats['favLocation']);
        sheetClasificacion.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: clasRowIndex)).value = TextCellValue(stats['favColor']);

        clasRowIndex++;
      }

      // --- HOJA 3: RÉCORDS Y PREMIOS (HALL OF FAME) ---
      final recHeaders = [
        "Premio",
        "Descripción",
        "Ganador",
        "Valor del Récord",
        "Fecha del Registro",
        "Detalles Adicionales"
      ];

      for (var col = 0; col < recHeaders.length; col++) {
        final cell = sheetRecords.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
        cell.value = TextCellValue(recHeaders[col]);
        cell.cellStyle = headerStyle;
      }

      final records = _calculateAnnualRecords(_filteredEvents);
      final KKEvent? heaviest = records['heaviest'];
      final KKEvent? longest = records['longest'];
      final KKEvent? shortest = records['shortest'];
      final KKEvent? earliest = records['earliest'];
      final KKEvent? latest = records['latest'];
      final String streakUser = records['streakUser'] ?? 'N/A';
      final int maxStreak = records['maxStreak'] ?? 0;

      final recordRows = [
        [
          "🏆 Jurásica Máxima",
          "Caca más pesada del periodo",
          heaviest?.displayName ?? 'N/A',
          heaviest != null ? "${heaviest.estimatedWeight} g" : 'N/A',
          heaviest != null ? dateFormat.format(heaviest.timestamp) : 'N/A',
          heaviest != null ? "Consistencia: ${heaviest.consistency.displayName}, Lugar: ${heaviest.location.displayName}" : ''
        ],
        [
          "👑 El Trono de Hierro",
          "Sesión más larga en el inodoro",
          longest?.displayName ?? 'N/A',
          longest != null ? "${(longest.duration! / 60.0).toStringAsFixed(1)} min" : 'N/A',
          longest != null ? dateFormat.format(longest.timestamp) : 'N/A',
          longest != null ? "Observaciones: ${longest.notes ?? 'Ninguna'}" : ''
        ],
        [
          "⚡ El Rayo",
          "Sesión más veloz registrada",
          shortest?.displayName ?? 'N/A',
          shortest != null ? "${shortest.duration} segundos" : 'N/A',
          shortest != null ? dateFormat.format(shortest.timestamp) : 'N/A',
          shortest != null ? "Consistencia: ${shortest.consistency.displayName}" : ''
        ],
        [
          "🔥 Constancia Absoluta",
          "Racha más larga de días seguidos",
          streakUser,
          "$maxStreak días",
          "N/A",
          "Días consecutivos registrando deposiciones"
        ],
        [
          "☀️ Caca de Oro Madrugadora",
          "Registro más temprano (05:00 - 11:59)",
          earliest?.displayName ?? 'N/A',
          earliest != null ? DateFormat('HH:mm').format(earliest.timestamp) : 'N/A',
          earliest != null ? dateFormat.format(earliest.timestamp) : 'N/A',
          earliest != null ? "Lugar: ${earliest.location.displayName}" : ''
        ],
        [
          "🦉 El Noctámbulo",
          "Registro más tardío (22:00 - 04:59)",
          latest?.displayName ?? 'N/A',
          latest != null ? DateFormat('HH:mm').format(latest.timestamp) : 'N/A',
          latest != null ? dateFormat.format(latest.timestamp) : 'N/A',
          latest != null ? "Lugar: ${latest.location.displayName}" : ''
        ],
      ];

      for (int i = 0; i < recordRows.length; i++) {
        for (int col = 0; col < recordRows[i].length; col++) {
          sheetRecords.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 1 + i)).value = TextCellValue(recordRows[i][col]);
        }
      }

      // --- HOJA 4: ANÁLISIS DE PATRONES ---
      final patHeaders = [
        "Usuario",
        "Lunes",
        "Martes",
        "Miércoles",
        "Jueves",
        "Viernes",
        "Sábado",
        "Domingo",
        "Madrugada (00-06)",
        "Mañana (06-12)",
        "Tarde (12-18)",
        "Noche (18-24)"
      ];

      for (var col = 0; col < patHeaders.length; col++) {
        final cell = sheetPatrones.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
        cell.value = TextCellValue(patHeaders[col]);
        cell.cellStyle = headerStyle;
      }

      int patRowIndex = 1;
      _filteredUserEventsMap.forEach((userId, events) {
        final username = _userNamesMap[userId] ?? 'Usuario';
        final patterns = _calculateTemporalPatterns(events);
        final weekdays = patterns['weekdays'] as Map<int, int>;
        final hourly = patterns['hourly'] as Map<String, int>;

        sheetPatrones.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: patRowIndex)).value = TextCellValue(username);
        
        for (int d = 1; d <= 7; d++) {
          sheetPatrones.cell(CellIndex.indexByColumnRow(columnIndex: d, rowIndex: patRowIndex)).value = IntCellValue(weekdays[d] ?? 0);
        }

        sheetPatrones.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: patRowIndex)).value = IntCellValue(hourly['Madrugada (00-06)'] ?? 0);
        sheetPatrones.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: patRowIndex)).value = IntCellValue(hourly['Mañana (06-12)'] ?? 0);
        sheetPatrones.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: patRowIndex)).value = IntCellValue(hourly['Tarde (12-18)'] ?? 0);
        sheetPatrones.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: patRowIndex)).value = IntCellValue(hourly['Noche (18-24)'] ?? 0);

        patRowIndex++;
      });

      // --- HOJA 5: HISTÓRICO DETALLADO ---
      final detailHeaders = [
        "ID Registro",
        "Usuario ID",
        "Nombre Usuario",
        "Fecha",
        "Hora",
        "Consistencia",
        "Color",
        "Ubicación",
        "Dificultad (1-5)",
        "Peso Estimado (g)",
        "Duración (seg)",
        "Latitud",
        "Longitud",
        "Notas"
      ];

      for (var col = 0; col < detailHeaders.length; col++) {
        final cell = sheetHistorico.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
        cell.value = TextCellValue(detailHeaders[col]);
        cell.cellStyle = headerStyle;
      }

      int detailRowIndex = 1;
      for (var event in _filteredEvents) {
        final username = event.displayName ?? _userNamesMap[event.userId] ?? 'Usuario Desconocido';
        
        sheetHistorico.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: detailRowIndex)).value = TextCellValue(event.id);
        sheetHistorico.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: detailRowIndex)).value = TextCellValue(event.userId);
        sheetHistorico.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: detailRowIndex)).value = TextCellValue(username);
        sheetHistorico.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: detailRowIndex)).value = TextCellValue(dateOnlyFormat.format(event.timestamp));
        sheetHistorico.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: detailRowIndex)).value = TextCellValue(timeOnlyFormat.format(event.timestamp));
        sheetHistorico.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: detailRowIndex)).value = TextCellValue(event.consistency.displayName);
        sheetHistorico.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: detailRowIndex)).value = TextCellValue(event.color.displayName);
        sheetHistorico.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: detailRowIndex)).value = TextCellValue(event.location.displayName);
        sheetHistorico.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: detailRowIndex)).value = IntCellValue(event.difficulty);
        sheetHistorico.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: detailRowIndex)).value = DoubleCellValue(event.estimatedWeight);
        sheetHistorico.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: detailRowIndex)).value = event.duration != null ? IntCellValue(event.duration!) : null;
        sheetHistorico.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: detailRowIndex)).value = event.latitude != null ? DoubleCellValue(event.latitude!) : null;
        sheetHistorico.cell(CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: detailRowIndex)).value = event.longitude != null ? DoubleCellValue(event.longitude!) : null;
        sheetHistorico.cell(CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: detailRowIndex)).value = event.notes != null ? TextCellValue(event.notes!) : null;

        detailRowIndex++;
      }

      // Guardar el archivo Excel
      final fileBytes = excel.save();
      if (fileBytes == null) {
        throw Exception("No se pudo generar los bytes del archivo Excel.");
      }

      String? path;
      Directory? downloadsDir;

      if (Platform.isWindows) {
        downloadsDir = await getDownloadsDirectory();
        if (downloadsDir != null) {
          path = "${downloadsDir.path}/estadisticas_kkpenco_$_selectedYear.xlsx";
        }
      }

      if (path == null) {
        final directory = await getTemporaryDirectory();
        path = "${directory.path}/estadisticas_kkpenco_$_selectedYear.xlsx";
      }

      final file = File(path);
      await file.writeAsBytes(fileBytes, flush: true);

      if (Platform.isWindows && downloadsDir != null) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
                side: const BorderSide(color: Colors.greenAccent, width: 1.5),
              ),
              title: const Row(
                children: [
                  Icon(Icons.file_download_done_rounded, color: Colors.greenAccent, size: 28),
                  SizedBox(width: 12),
                  Text(
                    '¡Descarga Completada!',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'El archivo Excel de estadísticas anuales se ha descargado correctamente en tu ordenador.',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF000000),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.folder_zip_rounded, color: Colors.amberAccent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SelectableText(
                            path!,
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.only(bottom: 16, right: 16),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    final Uri uri = Uri.file(downloadsDir!.path);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    }
                  },
                  icon: const Icon(Icons.folder_open_rounded),
                  label: const Text('Abrir Carpeta', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
      } else {
        // Compartir nativamente en móviles
        await Share.shareXFiles(
          [XFile(path)],
          text: 'Estadísticas de KKpenco 💩 ($_selectedYear) - Excel',
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar Excel: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: const Text('Estadísticas Anuales', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Selector de Año
          if (!_isLoading && _availableYears.isNotEmpty)
            DropdownButton<String>(
              value: _selectedYear,
              dropdownColor: const Color(0xFF1E1E1E),
              style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16),
              iconEnabledColor: Colors.greenAccent,
              underline: Container(),
              items: _availableYears.map((String year) {
                return DropdownMenuItem<String>(
                  value: year,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(year),
                  ),
                );
              }).toList(),
              onChanged: _onYearChanged,
            ),
          if (!_isLoading && _filteredEvents.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.file_download_rounded, color: Colors.greenAccent),
              tooltip: 'Exportar a Excel',
              onPressed: _exportToExcel,
            ),
          ]
        ],
      ),
      body: _isLoading
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ShimmerLoading(width: double.infinity, height: 180, borderRadius: 20),
                  const SizedBox(height: 20),
                  Row(
                    children: const [
                      Expanded(child: ShimmerLoading(width: double.infinity, height: 120, borderRadius: 16)),
                      SizedBox(width: 12),
                      Expanded(child: ShimmerLoading(width: double.infinity, height: 120, borderRadius: 16)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const ShimmerLoading(width: double.infinity, height: 260, borderRadius: 16),
                  const SizedBox(height: 20),
                  const ShimmerLoading(width: double.infinity, height: 200, borderRadius: 16),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 60),
                        const SizedBox(height: 16),
                        Text(_errorMessage!, style: const TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadData,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.brown[500]),
                          child: const Text('Reintentar'),
                        )
                      ],
                    ),
                  ),
                )
              : _filteredEvents.isEmpty
                  ? Center(
                      child: Text(
                        'No hay registros de cacas para el año $_selectedYear.',
                        style: const TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildOverallStatsCard(),
                          const SizedBox(height: 20),
                          _buildRecordsSection(),
                          const SizedBox(height: 20),
                          _buildConsistencyChart(),
                          const SizedBox(height: 20),
                          _buildUserRankingList(),
                          const SizedBox(height: 20),
                          _buildUserDetailDropdownSection(),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildOverallStatsCard() {
    final totalWeightKg = _totalWeightKg;
    final avgWeight = _avgWeight;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.brown[800]!, Colors.brown[900]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(76),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_rounded, color: Colors.amber, size: 28),
              const SizedBox(width: 8),
              Text(
                'Métricas del Periodo ($_selectedYear)',
                style: TextStyle(color: Colors.grey[200], fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatMetric('Total Cacas', '${_filteredEvents.length}', '💩'),
              _buildStatMetric('Peso Total', '${totalWeightKg.toStringAsFixed(1)} kg', '⚖️'),
              _buildStatMetric('Media/Caca', '${avgWeight.toStringAsFixed(0)} g', '🍽️'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatMetric(String label, String value, String emoji) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.grey[400], fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildRecordsSection() {
    final records = _calculateAnnualRecords(_filteredEvents);
    if (records.isEmpty) return const SizedBox.shrink();

    final KKEvent? heaviest = records['heaviest'];
    final KKEvent? longest = records['longest'];
    final KKEvent? shortest = records['shortest'];
    final KKEvent? earliest = records['earliest'];
    final KKEvent? latest = records['latest'];
    final String streakUser = records['streakUser'] ?? 'N/A';
    final int maxStreak = records['maxStreak'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Premios y Récords 🏆',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            mainAxisExtent: 135,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          children: [
            _buildRecordCard(
              'Jurásica Máxima',
              heaviest != null ? '${heaviest.displayName ?? 'Usuario'}\n${heaviest.estimatedWeight} g' : 'Sin registros',
              '👑 La más pesada',
              Colors.orange[400]!,
            ),
            _buildRecordCard(
              'Trono de Hierro',
              longest != null ? '${longest.displayName ?? 'Usuario'}\n${(longest.duration! / 60).round()} min' : 'Sin registros',
              '⏳ La sesión más larga',
              Colors.blue[400]!,
            ),
            _buildRecordCard(
              'El Rayo',
              shortest != null ? '${shortest.displayName ?? 'Usuario'}\n${shortest.duration} seg' : 'Sin registros',
              '⚡ La más rápida',
              Colors.yellow[600]!,
            ),
            _buildRecordCard(
              'Constancia Absoluta',
              maxStreak > 0 ? '$streakUser\n$maxStreak días 🔥' : 'Sin registros',
              '📅 Racha más larga',
              Colors.red[400]!,
            ),
            _buildRecordCard(
              'El Madrugador',
              earliest != null ? '${earliest.displayName ?? 'Usuario'}\n${DateFormat('HH:mm').format(earliest.timestamp)}' : 'Sin registros',
              '☀️ Caca más temprana',
              Colors.amber[400]!,
            ),
            _buildRecordCard(
              'El Noctámbulo',
              latest != null ? '${latest.displayName ?? 'Usuario'}\n${DateFormat('HH:mm').format(latest.timestamp)}' : 'Sin registros',
              '🦉 Caca más tardía',
              Colors.purple[300]!,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecordCard(String title, String value, String badge, Color accentColor) {
    String? username;
    String recordValue = value;
    final bool hasData = value != 'Sin registros';

    if (hasData && value.contains('\n')) {
      final parts = value.split('\n');
      username = parts[0];
      recordValue = parts[1];
    }

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF222222),
            Color(0xFF161616),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withAlpha(64), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accentColor.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Destello circular de neón sutil en la esquina superior derecha
          Positioned(
            top: -24,
            right: -24,
            child: CircleAvatar(
              radius: 44,
              backgroundColor: accentColor.withAlpha(20),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Cabecera: Badge con color
                Text(
                  badge,
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                // Cuerpo: Récord y Usuario
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!hasData)
                      const Text(
                        'Sin registros',
                        style: TextStyle(
                          color: Colors.white30,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    else ...[
                      Text(
                        recordValue,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline_rounded,
                            color: Colors.white54,
                            size: 11,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              username ?? 'Usuario',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                // Pie: Título del premio en una mini píldora translúcida
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accentColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    title,
                    style: TextStyle(
                      color: accentColor.withAlpha(220),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsistencyChart() {
    final total = _filteredEvents.length;
    final normalCount = _consistencyDistribution[Consistency.normal] ?? 0;
    final jurasicaCount = _consistencyDistribution[Consistency.jurasica] ?? 0;
    final espurruteoCount = _consistencyDistribution[Consistency.espurruteo] ?? 0;
    final cabraCount = _consistencyDistribution[Consistency.cabra] ?? 0;

    final normalPct = total == 0 ? 0.0 : normalCount / total;
    final jurasicaPct = total == 0 ? 0.0 : jurasicaCount / total;
    final espurruteoPct = total == 0 ? 0.0 : espurruteoCount / total;
    final cabraPct = total == 0 ? 0.0 : cabraCount / total;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Distribución de Consistencias',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 24,
              child: Row(
                children: [
                  if (normalCount > 0)
                    Expanded(
                      flex: normalCount,
                      child: Container(
                        color: Colors.green[600],
                        child: const Center(
                          child: Text(
                            'N',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ),
                    ),
                  if (jurasicaCount > 0)
                    Expanded(
                      flex: jurasicaCount,
                      child: Container(
                        color: Colors.brown[600],
                        child: const Center(
                          child: Text(
                            'J',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ),
                    ),
                  if (espurruteoCount > 0)
                    Expanded(
                      flex: espurruteoCount,
                      child: Container(
                        color: Colors.amber[700],
                        child: const Center(
                          child: Text(
                            'E',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ),
                    ),
                  if (cabraCount > 0)
                    Expanded(
                      flex: cabraCount,
                      child: Container(
                        color: Colors.grey[700],
                        child: const Center(
                          child: Text(
                            'C',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildLegendItem('Normal', Colors.green[600]!, normalPct),
              _buildLegendItem('Jurásica', Colors.brown[600]!, jurasicaPct),
              _buildLegendItem('Espurruteo', Colors.amber[700]!, espurruteoPct),
              _buildLegendItem('Cabra', Colors.grey[700]!, cabraPct),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, double percentage) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ${(percentage * 100).toStringAsFixed(0)}%',
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildUserRankingList() {
    final List<MapEntry<String, List<KKEvent>>> sortedUsers = _filteredUserEventsMap.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tabla de Deposiciones por Usuario',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedUsers.length,
            separatorBuilder: (_, __) => Divider(color: Colors.grey[800]),
            itemBuilder: (context, index) {
              final entry = sortedUsers[index];
              final username = _userNamesMap[entry.key] ?? 'Usuario Desconocido';
              final count = entry.value.length;
              final totalWeight = (_poopsWeightByUser[entry.key] ?? 0.0) / 1000.0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.grey[800],
                      radius: 16,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            username,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Peso Total: ${totalWeight.toStringAsFixed(2)} kg',
                            style: TextStyle(color: Colors.grey[500], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '$count 💩',
                      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUserDetailDropdownSection() {
    final filteredMap = _filteredUserEventsMap;
    if (filteredMap.isEmpty || _selectedUserId == null) {
      return const SizedBox.shrink();
    }

    final selectedEvents = filteredMap[_selectedUserId!] ?? [];
    final stats = _calculateStats(selectedEvents);
    final patterns = _calculateTemporalPatterns(selectedEvents);
    final String mostProductiveDay = patterns['mostProductiveDay'];
    final String mostProductiveHour = patterns['mostProductiveHour'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Detalle por Usuario',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              DropdownButton<String>(
                value: _selectedUserId,
                dropdownColor: const Color(0xFF1E1E1E),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                underline: Container(),
                items: filteredMap.keys.map((String userId) {
                  return DropdownMenuItem<String>(
                    value: userId,
                    child: Text(_userNamesMap[userId] ?? 'Usuario'),
                  );
                }).toList(),
                onChanged: (String? newUserId) {
                  if (newUserId != null) {
                    setState(() {
                      _selectedUserId = newUserId;
                    });
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _buildDetailItem('Media Semanal', '${(stats['weeklyAvg'] as double).toStringAsFixed(1)} / sem'),
              _buildDetailItem('Promedio Dificultad', '${(stats['avgDifficulty'] as double).toStringAsFixed(1)} / 5'),
              _buildDetailItem('Consistencia Favorita', stats['favConsistency']),
              _buildDetailItem('Ubicación Favorita', stats['favLocation']),
              _buildDetailItem('Color Favorito', stats['favColor']),
              _buildDetailItem('Duración Promedio', '${(stats['avgDuration'] as double).toStringAsFixed(0)} seg'),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.grey),
          const SizedBox(height: 8),
          const Text(
            'Patrones de Comportamiento 🕒',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDetailItem('Día Más Productivo', mostProductiveDay),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailItem('Horario Favorito', mostProductiveHour),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF000000),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
