import 'package:cloud_firestore/cloud_firestore.dart';

enum Consistency {
  normal('Normal', 300),
  jurasica('Jurásica', 750),
  espurruteo('Espurruteo', 150),
  cabra('Cabra', 50);

  final String displayName;
  final int baseWeight;
  const Consistency(this.displayName, this.baseWeight);

  static Consistency fromString(String value) {
    return Consistency.values.firstWhere(
      (e) => e.displayName.toLowerCase() == value.toLowerCase() || e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => Consistency.normal,
    );
  }
}

enum PoopColor {
  cafe('Marrón'),
  amarillo('Amarillo'),
  verde('Verde'),
  negro('Negro'),
  rojo('Rojo'),
  arcilla('Arcilla/Blanco');

  final String displayName;
  const PoopColor(this.displayName);

  static PoopColor fromString(String value) {
    return PoopColor.values.firstWhere(
      (e) => e.displayName.toLowerCase() == value.toLowerCase() || e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => PoopColor.cafe,
    );
  }
}

enum LocationTag {
  casa('Casa'),
  trabajo('Trabajo'),
  publico('Baño Público'),
  naturaleza('Naturaleza'),
  visita('Visita');

  final String displayName;
  const LocationTag(this.displayName);

  static LocationTag fromString(String value) {
    return LocationTag.values.firstWhere(
      (e) => e.displayName.toLowerCase() == value.toLowerCase() || e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => LocationTag.casa,
    );
  }
}

class KKEvent {
  final String id;
  final String userId;
  final String? displayName;
  final DateTime timestamp;
  final int? duration; // en segundos
  final Consistency consistency;
  final PoopColor color;
  final LocationTag location;
  final int difficulty; // escala 1-5
  final double estimatedWeight; // en gramos
  final String? notes;
  final double? latitude;
  final double? longitude;

  KKEvent({
    required this.id,
    required this.userId,
    this.displayName,
    required this.timestamp,
    this.duration,
    required this.consistency,
    required this.color,
    required this.location,
    required this.difficulty,
    required this.estimatedWeight,
    this.notes,
    this.latitude,
    this.longitude,
  });

  // Fórmula matemática para estimar el peso en gramos
  static double calculateWeight({
    required Consistency consistency,
    required int? durationSeconds, // Mantenido por compatibilidad
    required int difficulty,
  }) {
    double base = consistency.baseWeight.toDouble();

    // Dificultad (1-5, factor 1.0 a 1.2)
    double difficultyFactor = 1.0 + ((difficulty - 1) * 0.05);

    double calculated = base * difficultyFactor;
    
    // Variabilidad coherente
    double clamped = calculated.clamp(50.0, 1000.0);

    return double.parse(clamped.toStringAsFixed(1));
  }

  // Calcula la racha consecutiva de registros diarios
  static int calculateStreak(List<KKEvent> userEvents) {
    if (userEvents.isEmpty) return 0;

    final dates = userEvents
        .map((e) => DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day))
        .toSet()
        .toList();

    dates.sort((a, b) => b.compareTo(a));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (dates.first != today && dates.first != yesterday) {
      return 0;
    }

    int streak = 0;
    DateTime expectedDate = dates.first;

    for (var date in dates) {
      if (date == expectedDate) {
        streak++;
        expectedDate = expectedDate.subtract(const Duration(days: 1));
      } else if (date.isBefore(expectedDate)) {
        break;
      }
    }

    return streak;
  }

  factory KKEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final consistencyVal = Consistency.fromString(data['consistency'] ?? 'Normal');
    final durationVal = data['duration'];
    final difficultyVal = data['difficulty'] ?? 3;

    return KKEvent(
      id: doc.id,
      userId: data['userId'] ?? '',
      displayName: data['username'] as String?,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      duration: durationVal,
      consistency: consistencyVal,
      color: PoopColor.fromString(data['color'] ?? 'Marrón'),
      location: LocationTag.fromString(data['location'] ?? 'Casa'),
      difficulty: difficultyVal,
      estimatedWeight: (data['estimatedWeight'] ?? calculateWeight(
        consistency: consistencyVal,
        durationSeconds: durationVal,
        difficulty: difficultyVal,
      )).toDouble(),
      notes: data['notes'],
      latitude: data['latitude'] != null ? (data['latitude'] as num).toDouble() : null,
      longitude: data['longitude'] != null ? (data['longitude'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      if (displayName != null) 'username': displayName,
      'timestamp': Timestamp.fromDate(timestamp),
      if (duration != null) 'duration': duration,
      'consistency': consistency.displayName,
      'color': color.displayName,
      'location': location.displayName,
      'difficulty': difficulty,
      'estimatedWeight': estimatedWeight,
      if (notes != null) 'notes': notes,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }
}
