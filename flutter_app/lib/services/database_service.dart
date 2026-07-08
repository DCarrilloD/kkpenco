import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart'; // Para leer useMockData
import '../models/event.dart';
import '../models/chat_message.dart';
import '../models/achievement.dart';
import '../models/achievement_stats.dart';

// Estructura para paginación
class PagedEventsResult {
  final List<KKEvent> events;
  final Object? cursor; // DocumentSnapshot o String
  final bool hasMore;

  PagedEventsResult({required this.events, this.cursor, required this.hasMore});
}

class DatabaseService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;



  CollectionReference<KKEvent> get _eventsRef => _db.collection('events').withConverter<KKEvent>(
        fromFirestore: (snapshot, _) => KKEvent.fromFirestore(snapshot),
        toFirestore: (event, _) => event.toFirestore(),
      );

  CollectionReference<ChatMessage> get _chatRef => _db.collection('chat').withConverter<ChatMessage>(
        fromFirestore: (snapshot, _) => ChatMessage.fromFirestore(snapshot),
        toFirestore: (msg, _) => msg.toFirestore(),
      );

  // --- MOCK STORAGE EN MEMORIA ---
  static final List<KKEvent> _mockEvents = [
    KKEvent(
      id: 'mock_1',
      userId: 'mock_uid',
      displayName: 'David',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      duration: 300,
      consistency: Consistency.normal,
      color: PoopColor.cafe,
      location: LocationTag.trabajo,
      difficulty: 2,
      estimatedWeight: 157.5,
      notes: 'Todo perfecto en la oficina.',
    ),
    KKEvent(
      id: 'mock_2',
      userId: 'mock_uid',
      displayName: 'David',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      duration: 450,
      consistency: Consistency.jurasica,
      color: PoopColor.cafe,
      location: LocationTag.casa,
      difficulty: 4,
      estimatedWeight: 603.8,
      notes: 'Increíble esfuerzo. Valió la pena.',
    ),
  ];

  static final List<Map<String, dynamic>> _mockRankings = [
    {'uid': 'mock_uid', 'username': 'David', 'poopCount': 15, 'lastPoop': DateTime.now()},
    {'uid': 'user_2', 'username': 'Carlos', 'poopCount': 12, 'lastPoop': DateTime.now().subtract(const Duration(hours: 3))},
    {'uid': 'user_3', 'username': 'Elena', 'poopCount': 9, 'lastPoop': DateTime.now().subtract(const Duration(hours: 12))},
    {'uid': 'user_4', 'username': 'Sonia', 'poopCount': 5, 'lastPoop': DateTime.now().subtract(const Duration(days: 2))},
  ];

  static final List<Map<String, dynamic>> _mockMonthlyStats = [];

  static final List<ChatMessage> _mockChatMessages = [
    ChatMessage(id: 'c1', userId: 'user_2', displayName: 'Carlos', content: '¿Quién va ganando hoy?', timestamp: DateTime.now().subtract(const Duration(minutes: 10))),
    ChatMessage(id: 'c2', userId: 'user_3', displayName: 'Elena', content: '¡Yo llevo 2 hoy!', timestamp: DateTime.now().subtract(const Duration(minutes: 8))),
    ChatMessage(id: 'c3', userId: 'mock_uid', displayName: 'David', content: 'Jajaja qué locura, yo acabo de registrar una Jurásica.', timestamp: DateTime.now().subtract(const Duration(minutes: 5))),
  ];

  static final _eventsStreamController = StreamController<List<KKEvent>>.broadcast();
  static final _rankingStreamController = StreamController<List<Map<String, dynamic>>>.broadcast();
  static final _chatStreamController = StreamController<List<ChatMessage>>.broadcast();
  
  static final List<Map<String, dynamic>> _mockDuels = [];
  static final _duelsStreamController = StreamController<List<Map<String, dynamic>>>.broadcast();
  
  static final _achievementUnlockedStreamController = StreamController<String>.broadcast();
  static Stream<String> get onAchievementUnlocked => _achievementUnlockedStreamController.stream;

  // Presencia de escritura
  static final Map<String, String> _mockTypingUsers = {};
  static final _typingStreamController = StreamController<Map<String, String>>.broadcast();

  // Lista blanca Mock
  static final List<Map<String, dynamic>> _mockAuthorizedEmails = [
    {'email': 'admin@kkpenco.com', 'role': 'admin', 'registered': true},
    {'email': 'amigo@kkpenco.com', 'role': 'user', 'registered': false},
  ];
  static final _authorizedEmailsStreamController = StreamController<List<Map<String, dynamic>>>.broadcast();

  static bool _mockDataLoaded = false;

  DatabaseService() {
    // Configurar persistencia offline de Firestore
    if (!useMockData && !kIsWeb) {
      try {
        _db.settings = const Settings(persistenceEnabled: true);
      } catch (_) {}
    }
    if (useMockData && !_mockDataLoaded) {
      _mockDataLoaded = true;
      _loadMockData();
    }
  }

  static List<dynamic> _parseJsonBackground(String rawJson) {
    return jsonDecode(rawJson) as List<dynamic>;
  }

  static Future<void> _loadMockData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Cargar Eventos
      final eventsJson = prefs.getString('mock_events');
      if (eventsJson != null) {
        final List<dynamic> list = await compute(_parseJsonBackground, eventsJson);
        _mockEvents.clear();
        _mockEvents.addAll(list.map((m) => KKEvent(
          id: m['id'] ?? '',
          userId: m['userId'] ?? '',
          displayName: m['username'],
          timestamp: DateTime.tryParse(m['timestamp'] ?? '') ?? DateTime.now(),
          duration: m['duration'],
          consistency: Consistency.values.firstWhere((c) => c.name == m['consistency'] || c.displayName == m['consistency'], orElse: () => Consistency.normal),
          color: PoopColor.values.firstWhere((c) => c.name == m['color'] || c.displayName == m['color'], orElse: () => PoopColor.cafe),
          location: LocationTag.values.firstWhere((c) => c.name == m['location'] || c.displayName == m['location'], orElse: () => LocationTag.casa),
          difficulty: m['difficulty'] ?? 3,
          estimatedWeight: (m['estimatedWeight'] ?? 150.0).toDouble(),
          notes: m['notes'],
          latitude: m['latitude'] != null ? (m['latitude'] as num).toDouble() : null,
          longitude: m['longitude'] != null ? (m['longitude'] as num).toDouble() : null,
        )));
        _eventsStreamController.add(List.from(_mockEvents));
      }

      // Cargar Mensajes
      final chatJson = prefs.getString('mock_chat');
      if (chatJson != null) {
        final List<dynamic> list = await compute(_parseJsonBackground, chatJson);
        _mockChatMessages.clear();
        _mockChatMessages.addAll(list.map((m) => ChatMessage(
          id: m['id'] ?? '',
          userId: m['userId'] ?? '',
          displayName: m['username'] ?? '',
          content: m['content'] ?? '',
          timestamp: DateTime.tryParse(m['timestamp'] ?? '') ?? DateTime.now(),
          type: m['type'] ?? 'text',
          reactions: Map<String, List<String>>.from(
            (m['reactions'] as Map<String, dynamic>? ?? {}).map(
              (k, v) => MapEntry(k, List<String>.from(v ?? [])),
            ),
          ),
          metadata: m['metadata'] as Map<String, dynamic>?,
        )));
        _chatStreamController.add(List.from(_mockChatMessages));
      }

      // Cargar Rankings
      final rankingsJson = prefs.getString('mock_rankings');
      if (rankingsJson != null) {
        final List<dynamic> list = await compute(_parseJsonBackground, rankingsJson);
        _mockRankings.clear();
        _mockRankings.addAll(list.map((m) => {
          'uid': m['uid'] ?? '',
          'username': m['username'] ?? '',
          'poopCount': m['poopCount'] ?? 0,
          'lastPoop': DateTime.tryParse(m['lastPoop'] ?? '') ?? DateTime.now(),
          'currentStreak': m['currentStreak'] ?? 0,
          'maxStreak': m['maxStreak'] ?? 0,
        }));
        _rankingStreamController.add(List.from(_mockRankings));
      }
    } catch (e) {
      debugPrint('Error al cargar datos simulados: $e');
    }
  }

  static Future<void> _saveMockData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Guardar Eventos
      final eventsJson = jsonEncode(_mockEvents.map((e) => {
        'id': e.id,
        'userId': e.userId,
        'username': e.displayName,
        'timestamp': e.timestamp.toIso8601String(),
        'duration': e.duration,
        'consistency': e.consistency.name,
        'color': e.color.name,
        'location': e.location.name,
        'difficulty': e.difficulty,
        'estimatedWeight': e.estimatedWeight,
        'notes': e.notes,
        'latitude': e.latitude,
        'longitude': e.longitude,
      }).toList());
      await prefs.setString('mock_events', eventsJson);

      // Guardar Mensajes
      final chatJson = jsonEncode(_mockChatMessages.map((m) => {
        'id': m.id,
        'userId': m.userId,
        'username': m.displayName,
        'content': m.content,
        'timestamp': m.timestamp.toIso8601String(),
        'type': m.type,
        'reactions': m.reactions,
        'metadata': m.metadata,
      }).toList());
      await prefs.setString('mock_chat', chatJson);

      // Guardar Rankings
      final rankingsJson = jsonEncode(_mockRankings.map((r) => {
        'uid': r['uid'],
        'username': r['username'],
        'poopCount': r['poopCount'],
        'lastPoop': (r['lastPoop'] as DateTime).toIso8601String(),
        'currentStreak': r['currentStreak'] ?? 0,
        'maxStreak': r['maxStreak'] ?? 0,
      }).toList());
      await prefs.setString('mock_rankings', rankingsJson);
    } catch (e) {
      debugPrint('Error al guardar datos simulados: $e');
    }
  }

  // --- EVENTOS (TRACKER) ---

  // Agregar evento e incrementar contador del usuario en una transacción.
  // Devuelve el evento PERSISTIDO, con su ID real: la UI debe insertar ese en
  // su lista local (el que recibe puede traer un ID temporal que no coincide
  // con el doc, y borrar por ese ID fantasma fallaba siempre).
  // [waitForServerAck]: con la persistencia offline activada, el commit no
  // resuelve hasta el ack del servidor; la UI usa escritura optimista (false),
  // pero el widget de escritorio debe esperar o su isolate de background
  // moriría con la escritura solo en la cola local.
  Future<KKEvent> addEvent(KKEvent event, {bool waitForServerAck = false}) async {
    if (useMockData) {
      // Agregar al mock local
      final newMockEvent = KKEvent(
        id: 'mock_${DateTime.now().millisecondsSinceEpoch}',
        userId: event.userId,
        displayName: event.displayName,
        timestamp: event.timestamp,
        duration: event.duration,
        consistency: event.consistency,
        color: event.color,
        location: event.location,
        difficulty: event.difficulty,
        estimatedWeight: event.estimatedWeight,
        notes: event.notes,
        latitude: event.latitude,
        longitude: event.longitude,
      );
      _mockEvents.insert(0, newMockEvent);
      _eventsStreamController.add(List.from(_mockEvents));

      // Incrementar contador de ranking simulado
      for (var user in _mockRankings) {
        if (user['uid'] == event.userId || user['username'] == event.displayName) {
          user['poopCount'] = (user['poopCount'] as int) + 1;
          user['lastPoop'] = event.timestamp;
          break;
        }
      }
      _mockRankings.sort((a, b) => (b['poopCount'] as int).compareTo(a['poopCount'] as int));
      _rankingStreamController.add(List.from(_mockRankings));

      // Incrementar estadísticas mensuales simuladas
      final monthStr = "${event.timestamp.year}-${event.timestamp.month.toString().padLeft(2, '0')}";
      bool found = false;
      for (var stat in _mockMonthlyStats) {
        if (stat['userId'] == event.userId && stat['month'] == monthStr) {
          stat['count'] = (stat['count'] as int) + 1;
          stat['estimatedWeight'] = (stat['estimatedWeight'] as double) + event.estimatedWeight;
          found = true;
          break;
        }
      }
      if (!found) {
        _mockMonthlyStats.add({
          'userId': event.userId,
          'month': monthStr,
          'count': 1,
          'estimatedWeight': event.estimatedWeight,
        });
      }

      int kcoinsReward = 15;
      if (event.latitude != null) kcoinsReward += 10;
      if (event.difficulty >= 4) kcoinsReward += 5;
      if (event.notes != null && event.notes!.length > 20) kcoinsReward += 5;
      await addKcoins(event.userId, kcoinsReward);

      await _updateUserStreaks(event.userId, event.displayName);
      await _updateActiveDuelsCount(event.userId);
      await _checkAndUnlockAchievements(event);
      _saveMockData();
      return newMockEvent;
    }

    // El ID se genera ANTES del batch para poder devolver el evento con su ID
    // real (la regla de borrado de 5 minutos depende de que la UI lo tenga).
    final eventRef = _eventsRef.doc();
    final persistedEvent = KKEvent(
      id: eventRef.id,
      userId: event.userId,
      displayName: event.displayName,
      timestamp: event.timestamp,
      duration: event.duration,
      consistency: event.consistency,
      color: event.color,
      location: event.location,
      difficulty: event.difficulty,
      estimatedWeight: event.estimatedWeight,
      notes: event.notes,
      latitude: event.latitude,
      longitude: event.longitude,
    );
    final userRef = _db.collection('users').doc(event.userId);

    final monthStr = "${event.timestamp.year}-${event.timestamp.month.toString().padLeft(2, '0')}";
    final monthlyStatsRef = _db
        .collection('users')
        .doc(event.userId)
        .collection('monthly_stats')
        .doc(monthStr);

    // Leer el lastPoop PREVIO antes de que el batch lo sobrescriba: la racha
    // se compara contra el registro anterior, no contra el evento nuevo.
    final userSnap = await userRef.get();
    final userData = userSnap.data();
    final previousLastPoop = (userData?['lastPoop'] as Timestamp?)?.toDate();
    final currentStreak = userData?['currentStreak'] as int? ?? 0;
    final maxStreak = userData?['maxStreak'] as int? ?? 0;

    final newStreak = KKEvent.calculateIncrementalStreak(
      currentStreak: currentStreak,
      previousLastPoop: previousLastPoop,
      newEventDate: event.timestamp,
    );
    final newMaxStreak = newStreak > maxStreak ? newStreak : maxStreak;

    int kcoinsReward = 15;
    if (event.latitude != null) kcoinsReward += 10;
    if (event.difficulty >= 4) kcoinsReward += 5;
    if (event.notes != null && event.notes!.length > 20) kcoinsReward += 5;

    // Logros por contadores agregados (mejora 2.1): en vez de descargar la
    // colección `events` entera en cada guardado, se parte de los contadores
    // ya leídos en el doc del usuario, se les suma este evento y se evalúan los
    // logros contra ellos. Cero lecturas extra; una sola escritura en el batch.
    final newStats = AchievementStats.fromMap(
      userData?['achStats'] as Map<String, dynamic>?,
    ).fold(event);
    final existingAchievements =
        List<String>.from(userData?['achievements'] ?? const []);
    final unlockedAchievements = evaluateUnlockedAchievements(
      existing: existingAchievements,
      stats: newStats,
      currentStreak: newStreak,
      maxStreak: newMaxStreak,
      duelsCompleted: userData?['duelsCompleted'] as int? ?? 0,
      kcoins: (userData?['kcoins'] as int? ?? 0) + kcoinsReward,
    );

    final batch = _db.batch();

    // Registrar el evento con el ID ya generado
    batch.set(eventRef, persistedEvent);

    // Contador de por vida, rachas, Kakadólares, contadores de logros y los
    // logros recién desbloqueados, todo en la misma escritura atómica.
    // Nota: `achStats` se sobrescribe como mapa completo (no con increment),
    // así que dos addEvent verdaderamente simultáneos del mismo usuario podrían
    // perder un fold; poopCount/kcoins siguen con increment (seguros). Riesgo
    // muy bajo para un grupo de amigos.
    batch.update(userRef, {
      'poopCount': FieldValue.increment(1),
      'lastPoop': Timestamp.fromDate(event.timestamp),
      'currentStreak': newStreak,
      'maxStreak': newMaxStreak,
      'kcoins': FieldValue.increment(kcoinsReward),
      'achStats': newStats.toMap(),
      if (unlockedAchievements.isNotEmpty)
        'achievements': FieldValue.arrayUnion(unlockedAchievements),
    });

    // Incrementar estadísticas mensuales de forma atómica
    batch.set(monthlyStatsRef, {
      'count': FieldValue.increment(1),
      'estimatedWeight': FieldValue.increment(event.estimatedWeight),
      'month': monthStr,
    }, SetOptions(merge: true));

    // Notificar los logros desbloqueados para el popup de la UI (optimista: la
    // escritura ya está encolada y visible localmente).
    void emitUnlocked() {
      for (final id in unlockedAchievements) {
        _achievementUnlockedStreamController.add(id);
      }
    }

    // Lógica secundaria: solo el recuento de duelos activos (consulta la
    // colección `duels`). Los logros ya van resueltos en el batch.
    Future<void> runSecondaryLogic() async {
      await _updateActiveDuelsCount(event.userId);
    }

    if (waitForServerAck) {
      await batch.commit();
      emitUnlocked();
      await runSecondaryLogic();
    } else {
      // Escritura optimista: la persistencia deja la escritura encolada y
      // visible localmente al instante; no se bloquea la UI esperando el ack
      unawaited(batch.commit().catchError((e) {
        debugPrint('Error al confirmar el guardado del evento: $e');
      }));
      emitUnlocked();
      unawaited(runSecondaryLogic().catchError((e) {
        debugPrint('Error en la lógica secundaria de addEvent: $e');
      }));
    }
    return persistedEvent;
  }

  // Verificar si un usuario tiene el rol admin en Firestore o en la sesión simulada
  Future<bool> isAdminUser(String? uid) async {
    if (uid == null) return false;
    if (useMockData) {
      final email = AuthService().currentUser?.email ?? '';
      return email.contains('admin') || uid == 'mock_uid';
    }
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return false;
      final data = doc.data();
      return data?['role'] == 'admin';
    } catch (_) {
      return false;
    }
  }

  // Eliminar evento y actualizar contadores del usuario
  Future<void> deleteEvent(KKEvent event) async {
    // Validar seguridad de usuario y tiempo límite de 5 minutos (excepto si es administrador)
    final currentUserId = AuthService().currentUser?.uid;
    final bool isAdmin = await isAdminUser(currentUserId);

    if (event.userId != currentUserId && !isAdmin) {
      throw Exception("No tienes permisos para eliminar este registro.");
    }

    if (!isAdmin) {
      final diff = DateTime.now().difference(event.timestamp).inMinutes;
      if (diff >= 5) {
        throw Exception("Solo puedes eliminar registros durante los primeros 5 minutos.");
      }
    }

    if (useMockData) {
      _mockEvents.removeWhere((e) => e.id == event.id);
      _eventsStreamController.add(List.from(_mockEvents));

      // Decrementar contador en rankings
      for (var user in _mockRankings) {
        if (user['uid'] == event.userId || user['username'] == event.displayName) {
          int count = user['poopCount'] as int;
          if (count > 0) {
            user['poopCount'] = count - 1;
          }
          break;
        }
      }
      _mockRankings.sort((a, b) => (b['poopCount'] as int).compareTo(a['poopCount'] as int));
      _rankingStreamController.add(List.from(_mockRankings));

      // Decrementar estadísticas mensuales
      final monthStr = "${event.timestamp.year}-${event.timestamp.month.toString().padLeft(2, '0')}";
      for (var stat in _mockMonthlyStats) {
        if (stat['userId'] == event.userId && stat['month'] == monthStr) {
          int count = stat['count'] as int;
          if (count > 0) {
            stat['count'] = count - 1;
            stat['estimatedWeight'] = (stat['estimatedWeight'] as double) - event.estimatedWeight;
          }
          break;
        }
      }

      await _updateUserStreaks(event.userId, event.displayName);
      await _saveMockData();
      return;
    }

    final eventRef = _db.collection('events').doc(event.id);
    final userRef = _db.collection('users').doc(event.userId);

    final monthStr = "${event.timestamp.year}-${event.timestamp.month.toString().padLeft(2, '0')}";
    final monthlyStatsRef = _db
        .collection('users')
        .doc(event.userId)
        .collection('monthly_stats')
        .doc(monthStr);

    final batch = _db.batch();

    // Borrar el evento
    batch.delete(eventRef);

    // Decrementar el contador de deposiciones del usuario de por vida de forma segura
    batch.update(userRef, {
      'poopCount': FieldValue.increment(-1),
    });

    // Decrementar estadísticas mensuales de forma atómica
    batch.set(monthlyStatsRef, {
      'count': FieldValue.increment(-1),
      'estimatedWeight': FieldValue.increment(-event.estimatedWeight),
    }, SetOptions(merge: true));

    await batch.commit();

    await _updateUserStreaks(event.userId, event.displayName);
  }

  // Obtener flujo de eventos del usuario actual
  Stream<List<KKEvent>> getEvents(String userId) {
    if (useMockData) {
      Future.microtask(() => _eventsStreamController.add(List.from(_mockEvents)));
      // Mismo filtro por usuario que la query real, para que Windows/mock no
      // muestre el historial de todo el grupo.
      return _eventsStreamController.stream.map(
        (events) => events.where((e) => e.userId == userId).toList(),
      );
    }
    return _eventsRef
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => doc.data()).toList());
  }

  // Obtener todos los eventos del grupo (SOLO para la exportación CSV de
  // admin y estadísticas). El backup personal usa getUserEvents.
  // Usa [limit] en pantallas de visualización para acotar lecturas; déjalo nulo en exportaciones.
  Future<List<KKEvent>> getAllEvents({int? limit}) async {
    if (useMockData) {
      return List.from(limit != null ? _mockEvents.take(limit) : _mockEvents);
    }
    Query<KKEvent> query = _eventsRef.orderBy('timestamp', descending: true);
    if (limit != null) {
      query = query.limit(limit);
    }
    final snapshot = await query.get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // Eventos de UN usuario (para el backup personal: exportar los del grupo
  // entero y reasignarlos al restaurar corrompía los datos).
  Future<List<KKEvent>> getUserEvents(String userId) async {
    if (useMockData) {
      return _mockEvents.where((e) => e.userId == userId).toList();
    }
    final snapshot = await _eventsRef
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // --- PAGINACIÓN ---
  Future<PagedEventsResult> getEventsPaged(String userId, {int limit = 20, Object? cursor}) async {
    if (useMockData) {
      // Igual que la query real: solo los eventos del usuario
      final userEvents = _mockEvents.where((e) => e.userId == userId).toList();
      int startIndex = 0;
      if (cursor != null && cursor is String) {
        final idx = userEvents.indexWhere((e) => e.id == cursor);
        if (idx != -1) {
          startIndex = idx + 1;
        }
      }
      if (startIndex >= userEvents.length) {
        return PagedEventsResult(events: [], cursor: null, hasMore: false);
      }
      final endIndex = (startIndex + limit) > userEvents.length ? userEvents.length : (startIndex + limit);
      final events = userEvents.sublist(startIndex, endIndex);
      final hasMore = endIndex < userEvents.length;
      final nextCursor = events.isNotEmpty ? events.last.id : null;

      return PagedEventsResult(events: events, cursor: nextCursor, hasMore: hasMore);
    }

    Query<KKEvent> query = _eventsRef
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(limit);

    if (cursor != null && cursor is DocumentSnapshot) {
      query = query.startAfterDocument(cursor);
    }

    final snap = await query.get();
    final events = snap.docs.map((doc) => doc.data()).toList();
    final hasMore = snap.docs.length == limit;
    final nextCursor = snap.docs.isNotEmpty ? snap.docs.last : null;

    return PagedEventsResult(events: events, cursor: nextCursor, hasMore: hasMore);
  }

  // --- RANKING ---

  // Obtener flujo de usuarios ordenados por poopCount descendente
  Stream<List<Map<String, dynamic>>> getRanking() {
    if (useMockData) {
      _mockRankings.sort((a, b) => (b['poopCount'] as int).compareTo(a['poopCount'] as int));
      Future.microtask(() => _rankingStreamController.add(List.from(_mockRankings)));
      return _rankingStreamController.stream;
    }
    return _db
        .collection('users')
        .orderBy('poopCount', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'uid': doc.id,
                'username': data['username'] ?? 'Sin Nombre',
                'poopCount': data['poopCount'] ?? 0,
                'lastPoop': data['lastPoop'] != null
                    ? (data['lastPoop'] as Timestamp).toDate()
                    : null,
                // La UI del ranking también pinta racha, título y nudge; sin
                // estos campos solo aparecían en mock (por eso no se notaba).
                'currentStreak': data['currentStreak'] ?? 0,
                'maxStreak': data['maxStreak'] ?? 0,
                'equippedTitle': data['equippedTitle'],
                'photoURL': data['photoURL'],
              };
            }).toList());
  }

  // --- CHAT (COS) ---

  // Obtener flujo de mensajes de chat en tiempo real
  Stream<List<ChatMessage>> getChatMessages({int limit = 50}) {
    if (useMockData) {
      Future.microtask(() => _chatStreamController.add(List.from(_mockChatMessages)));
      // Respetar el limit como la query real: los últimos N en orden cronológico
      return _chatStreamController.stream.map((messages) =>
          messages.length <= limit ? messages : messages.sublist(messages.length - limit));
    }
    return _chatRef
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => doc.data())
            .toList()
            .reversed // Para que se muestren en orden cronológico en la pantalla
            .toList());
  }

  // Enviar mensaje de chat
  Future<void> sendChatMessage(ChatMessage message) async {
    if (useMockData) {
      final newMockMsg = ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        userId: message.userId,
        displayName: message.displayName,
        content: message.content,
        timestamp: message.timestamp,
        type: message.type,
        reactions: message.reactions,
        metadata: message.metadata,
      );
      _mockChatMessages.add(newMockMsg);
      _chatStreamController.add(List.from(_mockChatMessages));
      _saveMockData();
      
      if (message.type == 'share_poop') {
        await addKcoins(message.userId, 10);
        await unlockAchievement(message.userId, 'socializer', message.displayName);
      }
      if (message.type == 'image') {
        await addKcoins(message.userId, 15);
        final prefs = await SharedPreferences.getInstance();
        final count = (prefs.getInt('photo_count_${message.userId}') ?? 0) + 1;
        await prefs.setInt('photo_count_${message.userId}', count);
        if (count >= 5) {
          await unlockAchievement(message.userId, 'toilet_photo', message.displayName);
        }
      }
      return;
    }
    // Los mensajes de sistema van firmados con el uid real del emisor:
    // las reglas de Firestore exigen senderUid == request.auth.uid
    var messageToSend = message;
    if (message.userId == 'system' && message.senderUid == null) {
      messageToSend = message.copyWith(senderUid: AuthService().currentUser?.uid);
    }

    // Subir la foto a Storage y guardar la URL de descarga: la ruta local
    // solo existe en el dispositivo del emisor
    final localPath = message.metadata?['imagePath'] as String?;
    if (message.type == 'image' && localPath != null && !localPath.startsWith('http')) {
      final storageRef = FirebaseStorage.instance
          .ref('chat_images/${message.userId}/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await storageRef.putFile(
        File(localPath),
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final downloadUrl = await storageRef.getDownloadURL();
      messageToSend = messageToSend.copyWith(
        metadata: {...messageToSend.metadata!, 'imagePath': downloadUrl},
      );
    }

    await _chatRef.add(messageToSend);
    if (message.type == 'share_poop') {
      await addKcoins(message.userId, 10);
      await unlockAchievement(message.userId, 'socializer', message.displayName);
    }
    if (message.type == 'image') {
      await addKcoins(message.userId, 15);
      final userRef = _db.collection('users').doc(message.userId);
      await userRef.set({
        'photoCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
      final userSnap = await userRef.get();
      final count = userSnap.data()?['photoCount'] as int? ?? 0;
      if (count >= 5) {
        await unlockAchievement(message.userId, 'toilet_photo', message.displayName);
      }
    }
  }

  // Eliminar mensaje de chat (solo emisor o administrador)
  Future<void> deleteChatMessage(String messageId) async {
    final currentUserId = AuthService().currentUser?.uid;
    if (currentUserId == null) {
      throw Exception("Usuario no autenticado.");
    }

    if (useMockData) {
      _mockChatMessages.removeWhere((m) => m.id == messageId);
      _chatStreamController.add(List.from(_mockChatMessages));
      _saveMockData();
      return;
    }

    final docRef = _db.collection('chat').doc(messageId);
    final doc = await docRef.get();
    if (!doc.exists) {
      throw Exception("El mensaje no existe.");
    }

    final data = doc.data() as Map<String, dynamic>;
    final senderId = data['userId'] ?? '';
    final bool isAdmin = await isAdminUser(currentUserId);

    if (senderId == currentUserId || isAdmin) {
      await docRef.delete();
    } else {
      throw Exception("No tienes permisos para eliminar este mensaje.");
    }
  }

  // Actualizar los intentos y líderes de un reto de minijuego
  Future<void> updateChallengeAttempts(String messageId, String userId, String username, int score) async {
    if (useMockData) {
      for (int i = 0; i < _mockChatMessages.length; i++) {
        final msg = _mockChatMessages[i];
        if (msg.id == messageId) {
          final currentMeta = Map<String, dynamic>.from(msg.metadata ?? {});
          final attempts = Map<String, dynamic>.from(currentMeta['attempts'] ?? {});
          
          final currentBest = attempts[userId] as int? ?? 0;
          if (score > currentBest) {
            attempts[userId] = score;
          }
          currentMeta['attempts'] = attempts;
          
          final challengerScore = currentMeta['targetScore'] as int? ?? 0;
          final currentLeaderScore = currentMeta['leaderScore'] as int? ?? challengerScore;
          if (score > currentLeaderScore) {
            currentMeta['leaderName'] = username;
            currentMeta['leaderScore'] = score;
          }
          
          final updatedMsg = ChatMessage(
            id: msg.id,
            userId: msg.userId,
            displayName: msg.displayName,
            content: msg.content,
            timestamp: msg.timestamp,
            type: msg.type,
            reactions: msg.reactions,
            metadata: currentMeta,
          );
          _mockChatMessages[i] = updatedMsg;
          _chatStreamController.add(List.from(_mockChatMessages));
          _saveMockData();
          break;
        }
      }
      return;
    }
    
    final docRef = _db.collection('chat').doc(messageId);
    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(docRef);
      if (!snap.exists) return;
      
      final data = snap.data() as Map<String, dynamic>;
      final metadata = Map<String, dynamic>.from(data['metadata'] ?? {});
      final attempts = Map<String, dynamic>.from(metadata['attempts'] ?? {});
      
      final currentBest = attempts[userId] as int? ?? 0;
      if (score > currentBest) {
        attempts[userId] = score;
      }
      metadata['attempts'] = attempts;
      
      final challengerScore = metadata['targetScore'] as int? ?? 0;
      final currentLeaderScore = metadata['leaderScore'] as int? ?? challengerScore;
      if (score > currentLeaderScore) {
        metadata['leaderName'] = username;
        metadata['leaderScore'] = score;
      }
      
      transaction.update(docRef, {'metadata': metadata});
    });
  }

  // --- REACCIONES ---
  Future<void> reactToMessage(String messageId, String emoji, String userId) async {
    if (useMockData) {
      for (var msg in _mockChatMessages) {
        if (msg.id == messageId) {
          final currentList = List<String>.from(msg.reactions[emoji] ?? []);
          bool isAdding = false;
          if (currentList.contains(userId)) {
            currentList.remove(userId);
          } else {
            currentList.add(userId);
            isAdding = true;
          }
          final newReactions = Map<String, List<String>>.from(msg.reactions);
          if (currentList.isEmpty) {
            newReactions.remove(emoji);
          } else {
            newReactions[emoji] = currentList;
          }
          final newMsg = ChatMessage(
            id: msg.id,
            userId: msg.userId,
            displayName: msg.displayName,
            content: msg.content,
            timestamp: msg.timestamp,
            type: msg.type,
            reactions: newReactions,
            metadata: msg.metadata,
          );
          final idx = _mockChatMessages.indexOf(msg);
          _mockChatMessages[idx] = newMsg;
          _chatStreamController.add(List.from(_mockChatMessages));
          
          if (isAdding) {
            await addKcoins(userId, 2);
            final prefs = await SharedPreferences.getInstance();
            final countKey = 'reaction_count_$userId';
            final count = (prefs.getInt(countKey) ?? 0) + 1;
            await prefs.setInt(countKey, count);
            if (count >= 10) {
              await unlockAchievement(userId, 'critic', null);
            }
          }
          _saveMockData();
          break;
        }
      }
      return;
    }

    bool shouldUnlockCritic = false;
    bool wasAdded = false;
    final docRef = _db.collection('chat').doc(messageId);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;
      final data = snapshot.data() as Map<String, dynamic>;
      final reactionsData = data['reactions'] as Map<String, dynamic>? ?? {};
      
      final currentList = List<String>.from(reactionsData[emoji] ?? []);
      final bool isAdding = !currentList.contains(userId);
      wasAdded = isAdding;
      if (currentList.contains(userId)) {
        currentList.remove(userId);
      } else {
        currentList.add(userId);
      }

      reactionsData[emoji] = currentList;
      transaction.update(docRef, {'reactions': reactionsData});

      if (isAdding) {
        final userRef = _db.collection('users').doc(userId);
        final userSnap = await transaction.get(userRef);
        int currentCount = 0;
        if (userSnap.exists) {
          currentCount = userSnap.data()?['reactionsCount'] as int? ?? 0;
        }
        final newCount = currentCount + 1;
        transaction.set(userRef, {
          'reactionsCount': newCount,
        }, SetOptions(merge: true));
        
        if (newCount >= 10) {
          shouldUnlockCritic = true;
        }
      }
    });

    if (wasAdded) {
      await addKcoins(userId, 2);
    }
    if (shouldUnlockCritic) {
      await unlockAchievement(userId, 'critic', null);
    }
  }

  // --- PRESENCIA / ESCRITURA ---
  Future<void> setTypingStatus(String userId, String username, bool isTyping) async {
    if (useMockData) {
      if (isTyping) {
        _mockTypingUsers[userId] = username;
      } else {
        _mockTypingUsers.remove(userId);
      }
      _typingStreamController.add(Map.from(_mockTypingUsers));
      return;
    }

    final docRef = _db.collection('typing').doc(userId);
    if (isTyping) {
      await docRef.set({
        'username': username,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } else {
      await docRef.delete();
    }
  }

  Stream<Map<String, String>> getTypingUsers() {
    if (useMockData) {
      Future.microtask(() => _typingStreamController.add(Map.from(_mockTypingUsers)));
      return _typingStreamController.stream;
    }

    // Combina los snapshots de Firestore con un tick periódico para reevaluar el
    // filtro de frescura (8 s) aunque no llegue un snapshot nuevo: si alguien
    // cierra la app con typing=true, su doc queda huérfano y de otro modo los
    // demás lo verían "escribiendo…" hasta que otro evento disparase un snapshot.
    QuerySnapshot<Map<String, dynamic>>? lastSnap;

    Map<String, String> build() {
      final map = <String, String>{};
      final snap = lastSnap;
      if (snap == null) return map;
      for (var doc in snap.docs) {
        final timestamp = doc.data()['timestamp'] as Timestamp?;
        if (timestamp != null &&
            DateTime.now().difference(timestamp.toDate()).inSeconds < 8) {
          map[doc.id] = doc.data()['username'] ?? 'Usuario';
        }
      }
      return map;
    }

    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sub;
    Timer? ticker;
    late final StreamController<Map<String, String>> controller;
    controller = StreamController<Map<String, String>>(
      onListen: () {
        sub = _db.collection('typing').snapshots().listen((snap) {
          lastSnap = snap;
          controller.add(build());
        }, onError: controller.addError);
        ticker = Timer.periodic(const Duration(seconds: 3), (_) {
          if (lastSnap != null) controller.add(build());
        });
      },
      onCancel: () async {
        await sub?.cancel();
        ticker?.cancel();
      },
    );
    return controller.stream;
  }

  // Recalcular y actualizar rachas en base de datos (modo mock y borrados;
  // el alta con Firebase real actualiza la racha dentro del batch de addEvent)
  Future<void> _updateUserStreaks(String userId, String? username) async {
    try {
      if (useMockData) {
        final userEvents = _mockEvents.where((e) => e.userId == userId).toList();
        userEvents.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        final streak = KKEvent.calculateStreak(userEvents);

        // Buscar en _mockRankings
        bool found = false;
        for (var user in _mockRankings) {
          if (user['uid'] == userId) {
            final currentMax = user['maxStreak'] ?? 0;
            user['currentStreak'] = streak;
            user['maxStreak'] = streak > currentMax ? streak : currentMax;
            found = true;
            break;
          }
        }
        if (!found && username != null) {
          _mockRankings.add({
            'uid': userId,
            'username': username,
            'poopCount': 1,
            'lastPoop': DateTime.now(),
            'currentStreak': streak,
            'maxStreak': streak,
          });
        }
        return;
      }

      // Firestore real: solo se llama al borrar eventos. Al agregar, la racha
      // se calcula dentro del batch de addEvent con el lastPoop previo.
      final userRef = _db.collection('users').doc(userId);
      final userSnap = await userRef.get();
      final currentStreak = userSnap.data()?['currentStreak'] as int? ?? 0;
      final currentMax = userSnap.data()?['maxStreak'] as int? ?? 0;

      // Consultar dinámicamente limitando al tamaño de la racha actual + 2
      final limitCount = currentStreak > 0 ? (currentStreak + 2) : 5;
      final eventsSnapshot = await _db
          .collection('events')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(limitCount)
          .get();
      final events = eventsSnapshot.docs.map((doc) => KKEvent.fromFirestore(doc)).toList();
      final finalStreak = KKEvent.calculateStreak(events);
      final finalMaxStreak = finalStreak > currentMax ? finalStreak : currentMax;

      // Actualizar el documento de usuario
      await userRef.set({
        'currentStreak': finalStreak,
        'maxStreak': finalMaxStreak,
      }, SetOptions(merge: true));

    } catch (e) {
      debugPrint('Error al actualizar rachas del usuario: $e');
    }
  }

  // Obtener rachas del usuario
  Future<Map<String, int>> getUserStreaks(String userId) async {
    if (useMockData) {
      final userRank = _mockRankings.firstWhere(
        (u) => u['uid'] == userId,
        orElse: () => {'currentStreak': 0, 'maxStreak': 0},
      );
      return {
        'currentStreak': userRank['currentStreak'] ?? 0,
        'maxStreak': userRank['maxStreak'] ?? 0,
      };
    }

    try {
      final doc = await _db.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data();
        return {
          'currentStreak': data?['currentStreak'] ?? 0,
          'maxStreak': data?['maxStreak'] ?? 0,
        };
      }
    } catch (e) {
      debugPrint('Error al obtener rachas: $e');
    }
    return {'currentStreak': 0, 'maxStreak': 0};
  }

  Future<SharedPreferences> getSharedPreferences() async {
    return await SharedPreferences.getInstance();
  }

  Future<Map<String, dynamic>> getUserData(String userId) async {
    if (useMockData) {
      final prefs = await SharedPreferences.getInstance();
      final title = prefs.getString('equipped_title_$userId');
      final achievements = prefs.getStringList('unlocked_achievements_$userId') ?? ['first_poop'];
      return {
        'equippedTitle': title,
        'achievements': achievements,
      };
    }
    final doc = await _db.collection('users').doc(userId).get();
    return doc.data() ?? {};
  }

  // --- NOTIFICACIONES PUSH (token FCM y preferencias) ---

  // Preferencias por defecto: eventos activados (aviso base), duelos activados,
  // chat desactivado (opt-in desde el menú de Perfil). Las Cloud Functions usan
  // exactamente estos mismos defaults al decidir a quién enviar.
  static const Map<String, bool> defaultNotifPrefs = {
    'events': true,
    'duels': true,
    'chat': false,
  };

  // Guarda el token FCM del dispositivo en el doc del usuario.
  Future<void> saveFcmToken(String userId, String token) async {
    if (useMockData) return;
    await _db.collection('users').doc(userId).set({
      'fcmToken': token,
    }, SetOptions(merge: true));
  }

  // Borra el token FCM del doc del usuario (al cerrar sesión): sin esto el
  // dispositivo seguiría recibiendo los avisos de la cuenta antigua.
  Future<void> clearFcmToken(String userId) async {
    if (useMockData) return;
    try {
      await _db.collection('users').doc(userId).update({
        'fcmToken': FieldValue.delete(),
      });
    } catch (e) {
      // El doc puede no existir (cuenta recién borrada): nada que limpiar.
      debugPrint('Error al borrar el token FCM: $e');
    }
  }

  // Lee las preferencias de notificación, rellenando los que falten con los
  // defaults.
  Future<Map<String, bool>> getNotificationPrefs(String userId) async {
    if (useMockData) {
      final prefs = await SharedPreferences.getInstance();
      return {
        for (final e in defaultNotifPrefs.entries)
          e.key: prefs.getBool('notif_${e.key}_$userId') ?? e.value,
      };
    }
    final doc = await _db.collection('users').doc(userId).get();
    final raw = (doc.data()?['notifPrefs'] as Map<String, dynamic>?) ?? {};
    return {
      for (final e in defaultNotifPrefs.entries)
        e.key: raw[e.key] as bool? ?? e.value,
    };
  }

  // Guarda las preferencias de notificación del usuario.
  Future<void> updateNotificationPrefs(
      String userId, Map<String, bool> prefs) async {
    if (useMockData) {
      final sp = await SharedPreferences.getInstance();
      for (final e in prefs.entries) {
        await sp.setBool('notif_${e.key}_$userId', e.value);
      }
      return;
    }
    await _db.collection('users').doc(userId).set({
      'notifPrefs': prefs,
    }, SetOptions(merge: true));
  }

  Future<void> updateUserTitle(String userId, String? title) async {
    await _db.collection('users').doc(userId).set({
      'equippedTitle': title,
    }, SetOptions(merge: true));
  }

  Future<void> updateMockUserTitle(String userId, String? title) async {
    for (var r in _mockRankings) {
      if (r['uid'] == userId) {
        r['equippedTitle'] = title;
        break;
      }
    }
    _rankingStreamController.add(List.from(_mockRankings));
  }

  // --- LOOP DE MEJORA Y TIENDA ZEN (K-COINS / SKINS) ---
  Future<Map<String, dynamic>> getUserZenProfile(String userId) async {
    if (useMockData) {
      final prefs = await SharedPreferences.getInstance();
      final kcoins = prefs.getInt('zen_kcoins_$userId') ?? 50; // Inicia con 50 de regalo en mock
      final equippedSkin = prefs.getString('zen_equipped_skin_$userId') ?? '💩';
      final unlockedSkins = prefs.getStringList('zen_unlocked_skins_$userId') ?? ['💩'];
      final equippedTitle = prefs.getString('equipped_title_$userId');
      
      final activePowerups = {
        'shield': prefs.getBool('zen_powerup_shield_$userId') ?? false,
        'spring': prefs.getBool('zen_powerup_spring_$userId') ?? false,
        'magnet': prefs.getBool('zen_powerup_magnet_$userId') ?? false,
        'life': prefs.getBool('zen_powerup_life_$userId') ?? false,
        'passive_magnet': prefs.getBool('zen_passive_magnet_$userId') ?? false,
        'passive_insurance': prefs.getBool('zen_passive_insurance_$userId') ?? false,
      };

      return {
        'kcoins': kcoins,
        'equippedSkin': equippedSkin,
        'unlockedSkins': unlockedSkins,
        'equippedTitle': equippedTitle,
        'activePowerups': activePowerups,
      };
    }
    
    // Perfil por defecto: se usa si el documento no existe o si la lectura de
    // Firestore falla (sin conexión, primer arranque, etc.), para que entrar
    // al Modo Juanito nunca reviente con un error visible al usuario.
    Map<String, dynamic> defaultProfile() => {
      'kcoins': 0,
      'equippedSkin': '💩',
      'unlockedSkins': ['💩'],
      'equippedTitle': null,
      'activePowerups': {},
    };

    try {
      final doc = await _db.collection('users').doc(userId).get();
      if (!doc.exists) return defaultProfile();
      final data = doc.data();

      List<String> unlockedSkins = ['💩'];
      if (data?['unlockedSkins'] is Iterable) {
        unlockedSkins = (data!['unlockedSkins'] as Iterable).map((e) => e.toString()).toList();
      }

      return {
        'kcoins': data?['kcoins'] ?? 0,
        'equippedSkin': data?['equippedSkin'] ?? '💩',
        'unlockedSkins': unlockedSkins,
        'equippedTitle': data?['equippedTitle'],
        'activePowerups': data?['activePowerups'] ?? {},
      };
    } catch (e) {
      debugPrint('Error leyendo perfil Zen de Firestore: $e');
      return defaultProfile();
    }
  }

  Future<void> addKcoins(String userId, int amount) async {
    try {
      if (useMockData) {
        final prefs = await SharedPreferences.getInstance();
        final key = 'zen_kcoins_$userId';
        final current = prefs.getInt(key) ?? 50;
        final newAmt = (current + amount).clamp(0, 99999);
        await prefs.setInt(key, newAmt);
        
        // Actualizar localmente en rankings mock
        for (var user in _mockRankings) {
          if (user['uid'] == userId) {
            user['kcoins'] = newAmt;
            break;
          }
        }
        _rankingStreamController.add(List.from(_mockRankings));
        
        if (newAmt >= 500) {
          await unlockAchievement(userId, 'caca_capitalist', null);
        }
        return;
      }
      
      final userRef = _db.collection('users').doc(userId);
      await userRef.set({
        'kcoins': FieldValue.increment(amount),
      }, SetOptions(merge: true));

      // El logro solo puede desbloquearse con incrementos positivos, y una vez
      // desbloqueado (o verificado en esta sesión) no hace falta releer el
      // saldo tras cada increment: los minijuegos llaman esto muy a menudo.
      if (amount > 0 && !_capitalistDone.contains(userId)) {
        final doc = await userRef.get();
        final data = doc.data();
        final achievements = List<String>.from(data?['achievements'] ?? const []);
        if (achievements.contains('caca_capitalist')) {
          _capitalistDone.add(userId);
        } else if ((data?['kcoins'] as int? ?? 0) >= 500) {
          _capitalistDone.add(userId);
          await unlockAchievement(userId, 'caca_capitalist', null);
        }
      }
    } catch (e) {
      debugPrint('Error al agregar Kcoins: $e');
    }
  }

  // Usuarios con 'caca_capitalist' ya desbloqueado en esta sesión (evita un
  // get por cada addKcoins una vez conseguido el logro).
  static final Set<String> _capitalistDone = {};

  Future<bool> buySkin(String userId, String skin, int cost) async {
    try {
      if (useMockData) {
        final profile = await getUserZenProfile(userId);
        final kcoins = (profile['kcoins'] as num?)?.toInt() ?? 0;
        final unlocked = List<String>.from(profile['unlockedSkins']);

        if (kcoins < cost || unlocked.contains(skin)) {
          return false;
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('zen_kcoins_$userId', kcoins - cost);
        unlocked.add(skin);
        await prefs.setStringList('zen_unlocked_skins_$userId', unlocked);

        if (unlocked.length >= 3) {
          await unlockAchievement(userId, 'fashion_poop', null);
        }
        return true;
      }

      // Saldo y skins se validan DENTRO de la transacción (mismo patrón que
      // buyPowerupTransaction): validar con una lectura previa permitía que
      // dos compras simultáneas dejaran el saldo en negativo.
      final userRef = _db.collection('users').doc(userId);
      int skinsAfterPurchase = 0;
      final bought = await _db.runTransaction<bool>((transaction) async {
        final snap = await transaction.get(userRef);
        if (!snap.exists) return false;

        final data = snap.data();
        final currentCoins = data?['kcoins'] as int? ?? 0;
        final unlocked = (data?['unlockedSkins'] is Iterable)
            ? (data!['unlockedSkins'] as Iterable).map((e) => e.toString()).toList()
            : <String>['💩'];

        if (currentCoins < cost || unlocked.contains(skin)) return false;

        transaction.update(userRef, {
          'kcoins': FieldValue.increment(-cost),
          'unlockedSkins': FieldValue.arrayUnion([skin]),
        });
        skinsAfterPurchase = unlocked.length + 1;
        return true;
      });

      if (!bought) return false;

      if (skinsAfterPurchase >= 3) {
        await unlockAchievement(userId, 'fashion_poop', null);
      }
      return true;
    } catch (e) {
      debugPrint('Error al comprar skin: $e');
      return false;
    }
  }

  Future<bool> buyPowerupTransaction(String userId, String powerupId, int cost, {bool isPassive = false}) async {
    try {
      if (useMockData) {
        final prefs = await SharedPreferences.getInstance();
        final currentCoins = prefs.getInt('zen_kcoins_$userId') ?? 50;
        
        if (currentCoins < cost) return false;
        
        await prefs.setInt('zen_kcoins_$userId', currentCoins - cost);
        if (isPassive) {
          await prefs.setBool('zen_passive_${powerupId}_$userId', true);
        } else {
          await prefs.setBool('zen_powerup_${powerupId}_$userId', true);
        }
        
        // Actualizar localmente en rankings mock
        for (var user in _mockRankings) {
          if (user['uid'] == userId) {
            user['kcoins'] = currentCoins - cost;
            break;
          }
        }
        _rankingStreamController.add(List.from(_mockRankings));
        return true;
      }

      final userRef = _db.collection('users').doc(userId);
      return await _db.runTransaction<bool>((transaction) async {
        final snap = await transaction.get(userRef);
        if (!snap.exists) return false;
        
        final data = snap.data();
        final currentCoins = data?['kcoins'] as int? ?? 0;
        
        if (currentCoins < cost) return false;
        
        String dbKey = isPassive ? 'activePowerups.passive_$powerupId' : 'activePowerups.$powerupId';
        
        transaction.update(userRef, {
          'kcoins': FieldValue.increment(-cost),
          dbKey: true,
        });
        
        return true;
      });
    } catch (e) {
      debugPrint('Error en transacción de powerup: $e');
      return false;
    }
  }

  /// Gasta un power-up de un solo uso (shield/spring/magnet/life) al empezar
  /// una partida que lo aprovecha. Los pasivos no se consumen nunca.
  Future<void> consumePowerup(String userId, String powerupId) async {
    try {
      if (useMockData) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('zen_powerup_${powerupId}_$userId', false);
        return;
      }
      await _db.collection('users').doc(userId).set({
        'activePowerups': {powerupId: false},
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error al consumir powerup: $e');
    }
  }

  Future<void> equipSkin(String userId, String skin) async {
    try {
      if (useMockData) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('zen_equipped_skin_$userId', skin);
        return;
      }
      await _db.collection('users').doc(userId).set({
        'equippedSkin': skin,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error al equipar skin: $e');
    }
  }


  Future<void> unlockAchievement(String userId, String achievementId, String? username) async {
    try {
      if (useMockData) {
        final prefs = await SharedPreferences.getInstance();
        final key = 'unlocked_achievements_$userId';
        final list = prefs.getStringList(key) ?? ['first_poop'];
        if (!list.contains(achievementId)) {
          list.add(achievementId);
          await prefs.setStringList(key, list);
          
          _achievementUnlockedStreamController.add(achievementId);
        }
        return;
      }

      final userRef = _db.collection('users').doc(userId);
      final snap = await userRef.get();
      final list = List<String>.from(snap.data()?['achievements'] ?? []);
      if (!list.contains(achievementId)) {
        await userRef.set({
          'achievements': FieldValue.arrayUnion([achievementId]),
        }, SetOptions(merge: true));

        _achievementUnlockedStreamController.add(achievementId);
      }
    } catch (e) {
      debugPrint('Error al desbloquear logro: $e');
    }
  }

  Future<void> shareAchievementToChat(String userId, String username, String achievementId) async {
    try {
      final ach = Achievement.list.firstWhere((a) => a.id == achievementId);
      await sendChatMessage(ChatMessage(
        id: '',
        userId: 'system',
        displayName: 'Sistema 🏆',
        content: '¡$username ha desbloqueado el logro: *"${ach.title}"*! 🌟\n"${ach.description}"',
        timestamp: DateTime.now(),
        type: 'system',
      ));
    } catch (e) {
      debugPrint('Error al compartir logro en el chat: $e');
    }
  }

  // --- DUELOS 1v1 y NUDGES ---

  // Un duelo terminado se sigue mostrando (como resultado) durante estas horas
  // y después desaparece del banner.
  static const int _finishedDuelVisibleHours = 48;

  // ¿Debe aparecer el duelo en el banner? Pendientes y activos siempre; los
  // terminados solo como tarjeta de resultado durante un tiempo limitado (los
  // duelos 'finished' sin finishedAt son históricos y se ocultan).
  static bool _isDuelVisible(Map<String, dynamic> duel) {
    if (duel['status'] != 'finished') return true;
    final finishedAt = duel['finishedAt'];
    return finishedAt is DateTime &&
        DateTime.now().difference(finishedAt).inHours < _finishedDuelVisibleHours;
  }

  // Obtener flujo de duelos del usuario actual (en curso + resultados recientes)
  Stream<List<Map<String, dynamic>>> getActiveDuels(String userId) {
    if (useMockData) {
      Future.microtask(() => _duelsStreamController.add(List.from(_mockDuels)));
      return _duelsStreamController.stream.map(
        (duels) => duels.where(_isDuelVisible).toList(),
      );
    }
    return _db
        .collection('duels')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                ...data,
                'startDate': (data['startDate'] as Timestamp?)?.toDate(),
                'endDate': (data['endDate'] as Timestamp?)?.toDate(),
                'finishedAt': (data['finishedAt'] as Timestamp?)?.toDate(),
              };
            })
            .where(_isDuelVisible)
            .toList());
  }

  // Enviar un desafío de duelo 1v1
  Future<void> sendDuelChallenge(String targetUid, String targetUsername) async {
    final user = AuthService().currentUser;
    if (user == null) return;
    final challengerName = user.displayName;

    if (useMockData) {
      final newDuel = {
        'id': 'duel_${DateTime.now().millisecondsSinceEpoch}',
        'challengerId': user.uid,
        'challengerName': challengerName,
        'challengedId': targetUid,
        'challengedName': targetUsername,
        'startDate': DateTime.now(),
        'endDate': DateTime.now().add(const Duration(days: 7)),
        'challengerCount': 0,
        'challengedCount': 0,
        'status': 'pending',
        'participants': [user.uid, targetUid],
      };
      _mockDuels.add(newDuel);
      _duelsStreamController.add(List.from(_mockDuels));

      await sendChatMessage(ChatMessage(
        id: '',
        userId: 'system',
        displayName: 'Desafío ⚔️',
        content: '¡$challengerName ha desafiado a $targetUsername a un duelo de cacas de 7 días! 💩🔥',
        timestamp: DateTime.now(),
        type: 'system',
      ));
      return;
    }

    final duelRef = _db.collection('duels').doc();
    await duelRef.set({
      'challengerId': user.uid,
      'challengerName': challengerName,
      'challengedId': targetUid,
      'challengedName': targetUsername,
      'startDate': FieldValue.serverTimestamp(),
      'endDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
      'challengerCount': 0,
      'challengedCount': 0,
      'status': 'pending',
      'participants': [user.uid, targetUid],
    });

    await sendChatMessage(ChatMessage(
      id: '',
      userId: 'system',
      displayName: 'Desafío ⚔️',
      content: '¡$challengerName ha desafiado a $targetUsername a un duelo de cacas de 7 días! 💩🔥',
      timestamp: DateTime.now(),
      type: 'system',
    ));
  }

  // Aceptar un desafío de duelo 1v1
  Future<void> acceptDuelChallenge(String duelId) async {
    if (useMockData) {
      for (var d in _mockDuels) {
        if (d['id'] == duelId) {
          d['status'] = 'active';
          d['startDate'] = DateTime.now();
          d['endDate'] = DateTime.now().add(const Duration(days: 7));
          
          _duelsStreamController.add(List.from(_mockDuels));

          await sendChatMessage(ChatMessage(
            id: '',
            userId: 'system',
            displayName: 'Duelo Activo ⚔️',
            content: '¡El duelo entre ${d['challengerName']} y ${d['challengedName']} ha comenzado! Que gane el más regular. 💩🏁',
            timestamp: DateTime.now(),
            type: 'system',
          ));
          break;
        }
      }
      return;
    }

    final duelRef = _db.collection('duels').doc(duelId);
    final snap = await duelRef.get();
    if (!snap.exists) return;
    final data = snap.data();
    if (data == null) return;

    await duelRef.update({
      'status': 'active',
      'startDate': FieldValue.serverTimestamp(),
      'endDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
    });

    await sendChatMessage(ChatMessage(
      id: '',
      userId: 'system',
      displayName: 'Duelo Activo ⚔️',
      content: '¡El duelo entre ${data['challengerName']} y ${data['challengedName']} ha comenzado! Que gane el más regular. 💩🏁',
      timestamp: DateTime.now(),
      type: 'system',
    ));
  }

  // Enviar un empujón de racha (Nudge)
  Future<void> sendNudge(String targetUid, String targetUsername, int streak) async {
    final user = AuthService().currentUser;
    if (user == null) return;
    final challengerName = user.displayName;

    await sendChatMessage(ChatMessage(
      id: '',
      userId: 'system',
      displayName: 'Empujón ⚡',
      content: '¡$challengerName le ha dado un empujón a $targetUsername para que no pierda su racha de $streak días! 💩🏃‍♂️💨',
      timestamp: DateTime.now(),
      type: 'system',
    ));

    if (useMockData) {
      final prefs = await SharedPreferences.getInstance();
      final countKey = 'nudge_count_${user.uid}';
      final count = (prefs.getInt(countKey) ?? 0) + 1;
      await prefs.setInt(countKey, count);
      if (count >= 10) {
        await unlockAchievement(user.uid, 'nudge_master', challengerName);
      }
    } else {
      final userRef = _db.collection('users').doc(user.uid);
      await userRef.set({
        'nudgeCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
      final userSnap = await userRef.get();
      final count = userSnap.data()?['nudgeCount'] as int? ?? 0;
      if (count >= 10) {
        await unlockAchievement(user.uid, 'nudge_master', challengerName);
      }
    }
  }

  // Regla de fin de duelo, IDÉNTICA en mock y Firebase: gana el primero en
  // llegar a 5 puntos o, si nadie llega, el que vaya por delante al vencer
  // endDate (antes mock terminaba a 5 y Firebase solo por fecha, y en
  // producción un 5-0 seguía "en curso" durante días).
  static const int duelTargetScore = 5;

  Future<void> _updateActiveDuelsCount(String userId) async {
    try {
      if (useMockData) {
        final now = DateTime.now();
        for (var d in _mockDuels) {
          if (d['status'] == 'active' && d['participants'].contains(userId)) {
            final endDate = d['endDate'];
            final expired = endDate is DateTime && endDate.isBefore(now);

            // El punto del evento actual solo cuenta si el duelo sigue vivo
            if (!expired) {
              if (d['challengerId'] == userId) {
                d['challengerCount'] = (d['challengerCount'] as int) + 1;
              } else if (d['challengedId'] == userId) {
                d['challengedCount'] = (d['challengedCount'] as int) + 1;
              }
            }

            final chCount = d['challengerCount'] as int;
            final cdCount = d['challengedCount'] as int;
            if (expired || chCount >= duelTargetScore || cdCount >= duelTargetScore) {
              d['status'] = 'finished';
              d['finishedAt'] = DateTime.now();

              String winnerName = 'Empate';
              String? winnerId;
              if (chCount > cdCount) {
                winnerId = d['challengerId'];
                winnerName = d['challengerName'];
              } else if (cdCount > chCount) {
                winnerId = d['challengedId'];
                winnerName = d['challengedName'];
              }

              if (winnerId != null) {
                await unlockAchievement(winnerId, 'duelist', winnerName);
              }

              // Incrementar contador de duelos completados
              final prefs = await SharedPreferences.getInstance();
              for (var pId in d['participants']) {
                final key = 'duels_completed_$pId';
                final count = (prefs.getInt(key) ?? 0) + 1;
                await prefs.setInt(key, count);
                if (count >= 5) {
                  final pName = pId == d['challengerId'] ? d['challengerName'] : d['challengedName'];
                  await unlockAchievement(pId, 'duel_master', pName);
                }
              }

              await sendChatMessage(ChatMessage(
                id: '',
                userId: 'system',
                displayName: 'Duelo Finalizado 🏆',
                content: 'El duelo entre ${d['challengerName']} y ${d['challengedName']} ha terminado. ¡El ganador es: $winnerName! con un marcador de $chCount a $cdCount 💩',
                timestamp: DateTime.now(),
                type: 'system',
              ));
            }
          }
        }
        _duelsStreamController.add(List.from(_mockDuels));
        return;
      }

      final now = DateTime.now();
      final query = await _db
          .collection('duels')
          .where('status', isEqualTo: 'active')
          .where('participants', arrayContains: userId)
          .get();

      final batch = _db.batch();
      for (var doc in query.docs) {
        final data = doc.data();
        final endDate = (data['endDate'] as Timestamp?)?.toDate();
        final expired = endDate != null && endDate.isBefore(now);

        int chCount = data['challengerCount'] as int? ?? 0;
        int cdCount = data['challengedCount'] as int? ?? 0;

        // El punto del evento actual solo cuenta si el duelo sigue vivo
        if (!expired) {
          if (data['challengerId'] == userId) {
            chCount++;
          } else if (data['challengedId'] == userId) {
            cdCount++;
          }
        }

        if (expired || chCount >= duelTargetScore || cdCount >= duelTargetScore) {
          batch.update(doc.reference, {
            'status': 'finished',
            'challengerCount': chCount,
            'challengedCount': cdCount,
            'finishedAt': Timestamp.now(),
          });

          final chId = data['challengerId'] as String;
          final cdId = data['challengedId'] as String;
          final chName = data['challengerName'] as String;
          final cdName = data['challengedName'] as String;

          String winnerName = 'Empate';
          String? winnerId;
          if (chCount > cdCount) {
            winnerName = chName;
            winnerId = chId;
          } else if (cdCount > chCount) {
            winnerName = cdName;
            winnerId = cdId;
          }

          if (winnerId != null) {
            await unlockAchievement(winnerId, 'duelist', winnerName);
          }

          final chRef = _db.collection('users').doc(chId);
          final cdRef = _db.collection('users').doc(cdId);
          batch.set(chRef, {'duelsCompleted': FieldValue.increment(1)}, SetOptions(merge: true));
          batch.set(cdRef, {'duelsCompleted': FieldValue.increment(1)}, SetOptions(merge: true));

          await sendChatMessage(ChatMessage(
            id: '',
            userId: 'system',
            displayName: 'Duelo Finalizado 🏆',
            content: 'El duelo entre $chName y $cdName ha terminado. ¡El ganador es: $winnerName! con un marcador de $chCount a $cdCount 💩',
            timestamp: DateTime.now(),
            type: 'system',
          ));
        } else if (data['challengerId'] == userId) {
          batch.update(doc.reference, {'challengerCount': FieldValue.increment(1)});
        } else if (data['challengedId'] == userId) {
          batch.update(doc.reference, {'challengedCount': FieldValue.increment(1)});
        }
      }
      await batch.commit();

    } catch (e) {
      debugPrint('Error al actualizar contadores de duelos: $e');
    }
  }

  Future<void> _checkAndUnlockAchievements(KKEvent event) async {
    try {
      final userId = event.userId;
      final username = event.displayName;

      final userData = await getUserData(userId);
      final list = List<String>.from(userData['achievements'] ?? []);
      
      if (!list.contains('first_poop')) {
        await unlockAchievement(userId, 'first_poop', username);
      }

      if (event.duration != null && event.duration! < 60 && event.duration! > 0) {
        await unlockAchievement(userId, 'speedrunner', username);
      }

      if (event.duration != null && event.duration! > 1500) {
        await unlockAchievement(userId, 'meditator', username);
      }

      if (event.estimatedWeight > 500) {
        await unlockAchievement(userId, 'colossus', username);
      }

      if (event.estimatedWeight < 80) {
        await unlockAchievement(userId, 'feather', username);
      }

      if (event.location == LocationTag.naturaleza) {
        await unlockAchievement(userId, 'forest', username);
      }

      if (event.location == LocationTag.trabajo) {
        await unlockAchievement(userId, 'office', username);
      }

      final hour = event.timestamp.hour;
      if (hour >= 5 && hour < 8) {
        await unlockAchievement(userId, 'early_bird', username);
      }

      if (hour >= 0 && hour < 4) {
        await unlockAchievement(userId, 'night_owl', username);
      }

      final month = event.timestamp.month;
      final day = event.timestamp.day;
      if ((month == 12 && day == 25) || (month == 1 && day == 1)) {
        await unlockAchievement(userId, 'festive', username);
      }

      final allEvs = await getAllEvents();
      final userEvs = allEvs.where((e) => e.userId == userId).toList();
      userEvs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // explorer
      final geoEvents = userEvs.where((e) => e.latitude != null && e.longitude != null).toList();
      final distinctCoordinates = geoEvents.map((e) {
        return '${e.latitude!.toStringAsFixed(3)}_${e.longitude!.toStringAsFixed(3)}';
      }).toSet();
      if (distinctCoordinates.length >= 3) {
        await unlockAchievement(userId, 'explorer', username);
      }

      // worker_of_the_month (Trabajador del Mes)
      final monthStr = '${event.timestamp.year}-${event.timestamp.month}';
      final workEventsThisMonth = userEvs.where((e) => e.location == LocationTag.trabajo && '${e.timestamp.year}-${e.timestamp.month}' == monthStr).length;
      if (workEventsThisMonth >= 20) {
        await unlockAchievement(userId, 'worker_of_the_month', username);
      }

      // poop_rainbow
      final colors = userEvs.map((e) => e.color).toSet();
      if (colors.length >= 5) {
        await unlockAchievement(userId, 'poop_rainbow', username);
      }

      // poop_variety
      final consistencies = userEvs.map((e) => e.consistency).toSet();
      if (consistencies.length >= 3) {
        await unlockAchievement(userId, 'poop_variety', username);
      }

      // weight_champion
      final totalWeight = userEvs.fold(0.0, (acc, e) => acc + e.estimatedWeight);
      if (totalWeight >= 5000.0) {
        await unlockAchievement(userId, 'weight_champion', username);
      }

      // night_stalker
      final nightCacas = userEvs.where((e) => e.timestamp.hour >= 0 && e.timestamp.hour < 4).length;
      if (nightCacas >= 10) {
        await unlockAchievement(userId, 'night_stalker', username);
      }

      // speed_demon
      final speedCacas = userEvs.where((e) => e.duration != null && e.duration! < 60 && e.duration! > 0).length;
      if (speedCacas >= 5) {
        await unlockAchievement(userId, 'speed_demon', username);
      }

      // marathoner
      final longCacas = userEvs.where((e) => e.duration != null && e.duration! > 1500).length;
      if (longCacas >= 10) {
        await unlockAchievement(userId, 'marathoner', username);
      }

      // weekend_warrior
      final weekendCacas = userEvs.where((e) => e.timestamp.weekday == DateTime.saturday || e.timestamp.weekday == DateTime.sunday).length;
      if (weekendCacas >= 15) {
        await unlockAchievement(userId, 'weekend_warrior', username);
      }

      // double_drop & triple_drop
      final Map<String, int> poopsPerDay = {};
      for (var ev in userEvs) {
        final dayKey = '${ev.timestamp.year}-${ev.timestamp.month}-${ev.timestamp.day}';
        poopsPerDay[dayKey] = (poopsPerDay[dayKey] ?? 0) + 1;
      }
      final maxPoopsInOneDay = poopsPerDay.values.isEmpty ? 0 : poopsPerDay.values.fold<int>(0, (m, val) => val > m ? val : m);
      if (maxPoopsInOneDay >= 2) {
        await unlockAchievement(userId, 'double_drop', username);
      }
      if (maxPoopsInOneDay >= 3) {
        await unlockAchievement(userId, 'triple_drop', username);
      }

      // office_overtime
      final workOvertime = userEvs.any((e) => e.location == LocationTag.trabajo && (e.timestamp.hour >= 18 || e.timestamp.hour < 8));
      if (workOvertime) {
        await unlockAchievement(userId, 'office_overtime', username);
      }

      // green_peace
      final natureCacas = userEvs.where((e) => e.location == LocationTag.naturaleza).length;
      if (natureCacas >= 5) {
        await unlockAchievement(userId, 'green_peace', username);
      }

      // gps_mapper
      if (distinctCoordinates.length >= 10) {
        await unlockAchievement(userId, 'gps_mapper', username);
      }

      // perfect_attendance
      int consecutiveEasy = 0;
      bool has5ConsecutiveEasy = false;
      for (var ev in userEvs) {
        if (ev.difficulty == 1) {
          consecutiveEasy++;
          if (consecutiveEasy >= 5) {
            has5ConsecutiveEasy = true;
            break;
          }
        } else {
          consecutiveEasy = 0;
        }
      }
      if (has5ConsecutiveEasy) {
        await unlockAchievement(userId, 'perfect_attendance', username);
      }

      // hard_worker
      int consecutiveHard = 0;
      bool has5ConsecutiveHard = false;
      for (var ev in userEvs) {
        if (ev.difficulty == 5) {
          consecutiveHard++;
          if (consecutiveHard >= 5) {
            has5ConsecutiveHard = true;
            break;
          }
        } else {
          consecutiveHard = 0;
        }
      }
      if (has5ConsecutiveHard) {
        await unlockAchievement(userId, 'hard_worker', username);
      }

      // Streaks
      final streaks = await getUserStreaks(userId);
      final currentStreak = streaks['currentStreak'] ?? 0;
      final maxStreak = streaks['maxStreak'] ?? 0;
      if (currentStreak >= 15 || maxStreak >= 15) {
        await unlockAchievement(userId, 'streak_15', username);
      }
      if (currentStreak >= 7 || maxStreak >= 7) {
        await unlockAchievement(userId, 'streak_7', username);
      }
      if (currentStreak >= 3 || maxStreak >= 3) {
        await unlockAchievement(userId, 'streak_3', username);
      }
      if (currentStreak >= 30 || maxStreak >= 30) {
        await unlockAchievement(userId, 'streak_30', username);
      }
      if (currentStreak >= 50 || maxStreak >= 50) {
        await unlockAchievement(userId, 'streak_50', username);
      }

      // duel_master
      int duelsCompleted = 0;
      if (useMockData) {
        final prefs = await SharedPreferences.getInstance();
        duelsCompleted = prefs.getInt('duels_completed_$userId') ?? 0;
      } else {
        duelsCompleted = userData['duelsCompleted'] as int? ?? 0;
      }
      if (duelsCompleted >= 5) {
        await unlockAchievement(userId, 'duel_master', username);
      }

      // Logros Anuales de Larga Duración (se resetean al término del año)
      final currentYear = DateTime.now().year;
      final yearEventsCount = userEvs.where((e) => e.timestamp.year == currentYear).length;
      if (yearEventsCount >= 100) {
        await unlockAchievement(userId, 'year_poop_100', username);
      }
      if (yearEventsCount >= 200) {
        await unlockAchievement(userId, 'year_poop_200', username);
      }
      if (yearEventsCount >= 300) {
        await unlockAchievement(userId, 'year_poop_300', username);
      }
      if (yearEventsCount >= 400) {
        await unlockAchievement(userId, 'year_poop_400', username);
      }

      // Nuevos Logros Variados de Larga Duración
      final totalDurationSeconds = userEvs.fold(0, (acc, e) => acc + (e.duration ?? 0));
      if (totalDurationSeconds >= 36000) { // 10 horas en segundos
        await unlockAchievement(userId, 'time_marathoner_10h', username);
      }

      final outOfHomeCount = userEvs.where((e) => e.location != LocationTag.casa).length;
      if (outOfHomeCount >= 50) {
        await unlockAchievement(userId, 'out_of_home_50', username);
      }

      if (totalWeight >= 20000.0) { // 20 kg en gramos
        await unlockAchievement(userId, 'heavy_weight_20kg', username);
      }

      final hoursSet = userEvs.map((e) => e.timestamp.hour).toSet();
      if (hoursSet.length >= 12) {
        await unlockAchievement(userId, 'all_day_active', username);
      }

      final currentMonthStr = '${event.timestamp.year}-${event.timestamp.month}';
      final monthlyCount = userEvs.where((e) => '${e.timestamp.year}-${e.timestamp.month}' == currentMonthStr).length;
      if (monthlyCount >= 50) {
        await unlockAchievement(userId, 'monthly_poop_50', username);
      }

      // Nuevos logros variados de larga duración
      final yearEvents = userEvs.where((e) => e.timestamp.year == currentYear).toList();
      
      // monthly_consistency_12 (Calendario Completo)
      final monthsSet = yearEvents.map((e) => e.timestamp.month).toSet();
      if (monthsSet.length >= 12) {
        await unlockAchievement(userId, 'monthly_consistency_12', username);
      }

      // four_seasons (Las Cuatro Estaciones)
      final seasons = yearEvents.map((e) {
        final m = e.timestamp.month;
        if (m >= 3 && m <= 5) return 'primavera';
        if (m >= 6 && m <= 8) return 'verano';
        if (m >= 9 && m <= 11) return 'otono';
        return 'invierno';
      }).toSet();
      if (seasons.length >= 4) {
        await unlockAchievement(userId, 'four_seasons', username);
      }

      // gps_nomad_30 (El GeoCagador Profesional)
      if (distinctCoordinates.length >= 30) {
        await unlockAchievement(userId, 'gps_nomad_30', username);
      }

      // year_active_days_100 (Constancia del Hábito)
      final activeDaysSet = yearEvents.map((e) => '${e.timestamp.year}-${e.timestamp.month}-${e.timestamp.day}').toSet();
      if (activeDaysSet.length >= 100) {
        await unlockAchievement(userId, 'year_active_days_100', username);
      }

      // regularity_expert_100 (El Reloj de Cuco)
      final Map<int, int> hourCounts = {};
      for (var ev in userEvs) {
        final hr = ev.timestamp.hour;
        hourCounts[hr] = (hourCounts[hr] ?? 0) + 1;
      }
      final hasFavoriteHour100 = hourCounts.values.any((c) => c >= 100);
      if (hasFavoriteHour100) {
        await unlockAchievement(userId, 'regularity_expert_100', username);
      }

      // weight_titan_100kg (Excavador Continental)
      if (totalWeight >= 100000.0) { // 100 kg en gramos
        await unlockAchievement(userId, 'weight_titan_100kg', username);
      }

    } catch (e) {
      debugPrint('Error al verificar logros: $e');
    }
  }

  // SOLO modo simulación. En producción el borrado completo lo hace la Cloud
  // Function `deleteMyAccount` (vía AuthService.deleteMyAccountRemote): el
  // antiguo batch de cliente era imposible con las reglas actuales (el dueño
  // no puede borrar su doc de `users` ni eventos de más de 5 minutos, y
  // tocaba colecciones sin reglas), así que fallaba SIEMPRE.
  Future<void> deleteAllUserData(String uid) async {
    if (!useMockData) {
      throw UnsupportedError(
        'En producción el borrado de cuenta se hace con la Cloud Function deleteMyAccount.',
      );
    }

    // 1. Eliminar eventos de mock
    _mockEvents.removeWhere((e) => e.userId == uid);
    _eventsStreamController.add(List.from(_mockEvents));

    // 2. Eliminar rankings de mock
    _mockRankings.removeWhere((r) => r['uid'] == uid);
    _rankingStreamController.add(List.from(_mockRankings));

    // 3. Limpiar SharedPreferences locales del simulador
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('high_score_caca_catch');
    await prefs.remove('high_score_flappy_poop');
    await prefs.remove('high_score_toilet_jump');
    await prefs.remove('high_score_poop_invaders');
    await prefs.remove('mock_events');
    await prefs.remove('mock_rankings');
    await prefs.remove('zen_profile_$uid');
    await prefs.remove('achievements_$uid');
    await prefs.remove('zen_kcoins_$uid');
    await prefs.remove('zen_equipped_skin_$uid');
    await prefs.remove('zen_unlocked_skins_$uid');
    await prefs.remove('unlocked_achievements_$uid');
    await prefs.remove('equipped_title_$uid');
    _saveMockData();
  }

  // Restaura el historial PROPIO del usuario desde un backup. El llamador
  // (perfil) ya descarta los eventos cuyo userId original no sea el propio;
  // aquí además se generan SIEMPRE IDs nuevos: reutilizar los del JSON podía
  // chocar con (y sobreescribir) documentos de otros usuarios.
  Future<void> importBackupEvents(String uid, String username, List<KKEvent> events) async {
    if (useMockData) {
      // 1. Eliminar eventos antiguos de mock del usuario
      _mockEvents.removeWhere((e) => e.userId == uid);

      // 2. Insertar todos los nuevos eventos
      final rand = Random();
      for (var ev in events) {
        // Sobreescribir id y userId por seguridad; el nombre se conserva del
        // propio backup (histórico) y solo cae al del perfil actual si el
        // registro no traía uno.
        final securedEvent = KKEvent(
          id: 'mock_${DateTime.now().millisecondsSinceEpoch}_${rand.nextInt(10000)}',
          userId: uid,
          displayName: ev.displayName ?? username,
          timestamp: ev.timestamp,
          duration: ev.duration,
          consistency: ev.consistency,
          color: ev.color,
          location: ev.location,
          difficulty: ev.difficulty,
          estimatedWeight: ev.estimatedWeight,
          notes: ev.notes,
          latitude: ev.latitude,
          longitude: ev.longitude,
        );
        _mockEvents.add(securedEvent);
      }
      
      // Ordenar por fecha descendente
      _mockEvents.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      _eventsStreamController.add(List.from(_mockEvents));

      // 3. Recalcular contadores en rankings
      bool userRankingFound = false;
      for (var user in _mockRankings) {
        if (user['uid'] == uid) {
          user['poopCount'] = events.length;
          user['lastPoop'] = events.isEmpty ? DateTime.now() : events.map((e) => e.timestamp).reduce((a, b) => a.isAfter(b) ? a : b);
          user['username'] = username;
          userRankingFound = true;
          break;
        }
      }
      if (!userRankingFound) {
        _mockRankings.add({
          'uid': uid,
          'username': username,
          'poopCount': events.length,
          'lastPoop': events.isEmpty ? DateTime.now() : events.map((e) => e.timestamp).reduce((a, b) => a.isAfter(b) ? a : b),
          'currentStreak': 0,
          'maxStreak': 0,
        });
      }
      _mockRankings.sort((a, b) => (b['poopCount'] as int).compareTo(a['poopCount'] as int));
      _rankingStreamController.add(List.from(_mockRankings));

      // 4. Recalcular estadísticas mensuales simuladas
      _mockMonthlyStats.removeWhere((stat) => stat['userId'] == uid);
      final Map<String, List<KKEvent>> groupedByMonth = {};
      for (var ev in events) {
        final monthStr = "${ev.timestamp.year}-${ev.timestamp.month.toString().padLeft(2, '0')}";
        groupedByMonth.putIfAbsent(monthStr, () => []).add(ev);
      }
      groupedByMonth.forEach((monthStr, list) {
        final totalWeight = list.fold(0.0, (double sum, e) => sum + e.estimatedWeight);
        _mockMonthlyStats.add({
          'userId': uid,
          'month': monthStr,
          'count': list.length,
          'estimatedWeight': totalWeight,
        });
      });

      _saveMockData();
      return;
    }

    // En producción (Firestore):
    // Helper: commit en lotes de máximo 500 operaciones (límite de Firestore;
    // con historial largo un batch único revienta)
    Future<void> deleteInChunks(List<DocumentReference> refs) async {
      for (int i = 0; i < refs.length; i += 500) {
        final batch = _db.batch();
        for (final ref in refs.skip(i).take(500)) {
          batch.delete(ref);
        }
        await batch.commit();
      }
    }

    // 1. Borrar eventos antiguos del usuario
    final eventsQuery = await _db.collection('events').where('userId', isEqualTo: uid).get();
    await deleteInChunks(eventsQuery.docs.map((d) => d.reference).toList());

    // 2. Insertar los nuevos eventos en lotes de máximo 500 documentos por batch
    int index = 0;
    while (index < events.length) {
      final batch = _db.batch();
      final chunk = events.skip(index).take(500);
      for (var ev in chunk) {
        // ID SIEMPRE nuevo: reutilizar el del JSON podía pisar docs ajenos.
        // displayName: se conserva el del propio backup; solo cae al del
        // perfil actual si el registro no traía uno.
        final securedEvent = KKEvent(
          id: _db.collection('events').doc().id,
          userId: uid,
          displayName: ev.displayName ?? username,
          timestamp: ev.timestamp,
          duration: ev.duration,
          consistency: ev.consistency,
          color: ev.color,
          location: ev.location,
          difficulty: ev.difficulty,
          estimatedWeight: ev.estimatedWeight,
          notes: ev.notes,
          latitude: ev.latitude,
          longitude: ev.longitude,
        );
        final docRef = _db.collection('events').doc(securedEvent.id);
        batch.set(docRef, securedEvent.toFirestore());
      }
      await batch.commit();
      index += 500;
    }

    // 3. Recalcular estadísticas mensuales en users/{uid}/monthly_stats
    final monthlyStatsQuery = await _db
        .collection('users')
        .doc(uid)
        .collection('monthly_stats')
        .get();
    await deleteInChunks(monthlyStatsQuery.docs.map((d) => d.reference).toList());

    final Map<String, List<KKEvent>> groupedByMonth = {};
    for (var ev in events) {
      final monthStr = "${ev.timestamp.year}-${ev.timestamp.month.toString().padLeft(2, '0')}";
      groupedByMonth.putIfAbsent(monthStr, () => []).add(ev);
    }

    final statsBatch = _db.batch();
    groupedByMonth.forEach((monthStr, list) {
      final monthlyStatsRef = _db
          .collection('users')
          .doc(uid)
          .collection('monthly_stats')
          .doc(monthStr);
      final totalWeight = list.fold(0.0, (double sum, e) => sum + e.estimatedWeight);
      statsBatch.set(monthlyStatsRef, {
        'count': list.length,
        'estimatedWeight': totalWeight,
        'month': monthStr,
      }, SetOptions(merge: true));
    });

    // 4. Recalcular contadores del doc de usuario desde los eventos importados:
    // poopCount/lastPoop, rachas y achStats (dejarlo desincronizado rompía la
    // evaluación incremental de logros de addEvent).
    final sortedByDate = List<KKEvent>.from(events)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final rebuiltStats = AchievementStats();
    for (final ev in sortedByDate) {
      rebuiltStats.fold(ev);
    }

    final newestFirst = sortedByDate.reversed.toList();
    final streak = KKEvent.calculateStreak(newestFirst);

    final userRef = _db.collection('users').doc(uid);
    statsBatch.update(userRef, {
      'poopCount': events.length,
      if (newestFirst.isNotEmpty)
        'lastPoop': Timestamp.fromDate(newestFirst.first.timestamp),
      'achStats': rebuiltStats.toMap(),
      'currentStreak': streak,
    });

    await statsBatch.commit();
  }

  // Repara registros propios grabados como "Sin Nombre" (o sin nombre) por el
  // desajuste entre el displayName de Auth y el username de Firestore — ver
  // AuthService.syncDisplayNameFromFirestore. Se dispara desde "editar
  // perfil" al confirmar el nombre; solo toca eventos del propio uid.
  Future<int> backfillMissingDisplayNames(String uid, String correctName) async {
    if (useMockData) {
      int fixed = 0;
      for (var i = 0; i < _mockEvents.length; i++) {
        final ev = _mockEvents[i];
        if (ev.userId == uid && (ev.displayName == null || ev.displayName == 'Sin Nombre')) {
          _mockEvents[i] = KKEvent(
            id: ev.id,
            userId: ev.userId,
            displayName: correctName,
            timestamp: ev.timestamp,
            duration: ev.duration,
            consistency: ev.consistency,
            color: ev.color,
            location: ev.location,
            difficulty: ev.difficulty,
            estimatedWeight: ev.estimatedWeight,
            notes: ev.notes,
            latitude: ev.latitude,
            longitude: ev.longitude,
          );
          fixed++;
        }
      }
      if (fixed > 0) _eventsStreamController.add(List.from(_mockEvents));
      return fixed;
    }

    final snap = await _eventsRef.where('userId', isEqualTo: uid).get();
    final toFix = snap.docs.where((doc) {
      final name = doc.data().displayName;
      return name == null || name == 'Sin Nombre';
    }).toList();

    for (int i = 0; i < toFix.length; i += 500) {
      final batch = _db.batch();
      for (final doc in toFix.skip(i).take(500)) {
        batch.update(doc.reference, {'username': correctName});
      }
      await batch.commit();
    }
    return toFix.length;
  }

  // --- GESTIÓN DE LISTA BLANCA (WHITELIST) ---
  
  // Obtener flujo de la lista blanca de correos autorizados
  Stream<List<Map<String, dynamic>>> getAuthorizedEmails() {
    if (useMockData) {
      Future.microtask(() => _authorizedEmailsStreamController.add(List.from(_mockAuthorizedEmails)));
      return _authorizedEmailsStreamController.stream;
    }
    return _db
        .collection('authorized_emails')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'email': doc.id,
                'role': data['role'] ?? 'user',
                'registered': data['registered'] ?? false,
                'addedAt': data['addedAt'] != null
                    ? (data['addedAt'] as Timestamp).toDate()
                    : null,
              };
            }).toList());
  }

  // Autorizar un nuevo email en la lista blanca
  Future<void> authorizeEmail(String email, String role) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) throw Exception("El correo electrónico no puede estar vacío.");

    if (useMockData) {
      // Verificar si ya existe
      if (_mockAuthorizedEmails.any((e) => e['email'] == cleanEmail)) {
        throw Exception("Este correo ya está en la lista blanca.");
      }
      _mockAuthorizedEmails.add({
        'email': cleanEmail,
        'role': role,
        'registered': false,
        'addedAt': DateTime.now(),
      });
      _authorizedEmailsStreamController.add(List.from(_mockAuthorizedEmails));
      return;
    }

    final docRef = _db.collection('authorized_emails').doc(cleanEmail);
    final doc = await docRef.get();
    if (doc.exists) {
      throw Exception("Este correo ya está en la lista blanca.");
    }

    await docRef.set({
      'role': role,
      'registered': false,
      'addedAt': FieldValue.serverTimestamp(),
    });
  }

  // Revocar acceso a un email de la lista blanca (eliminarlo)
  Future<void> revokeEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();

    if (useMockData) {
      _mockAuthorizedEmails.removeWhere((e) => e['email'] == cleanEmail);
      _authorizedEmailsStreamController.add(List.from(_mockAuthorizedEmails));
      return;
    }

    await _db.collection('authorized_emails').doc(cleanEmail).delete();
  }
}
