import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart'; // Para leer useMockData
import '../models/event.dart';
import '../models/chat_message.dart';
import '../models/achievement.dart';
import '../models/app_user.dart';

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

  static Future<void> _loadMockData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Cargar Eventos
      final eventsJson = prefs.getString('mock_events');
      if (eventsJson != null) {
        final List<dynamic> list = jsonDecode(eventsJson);
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
        final List<dynamic> list = jsonDecode(chatJson);
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
        final List<dynamic> list = jsonDecode(rankingsJson);
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

  // Agregar evento e incrementar contador del usuario en una transacción
  Future<void> addEvent(KKEvent event) async {
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

      await _updateUserStreaks(event.userId, event.displayName, isDeletion: false, newEventDate: event.timestamp);
      await _updateActiveDuelsCount(event.userId);
      await _checkAndUnlockAchievements(event);
      _saveMockData();
      return;
    }

    final eventRef = _eventsRef.doc();
    final userRef = _db.collection('users').doc(event.userId);

    final monthStr = "${event.timestamp.year}-${event.timestamp.month.toString().padLeft(2, '0')}";
    final monthlyStatsRef = _db
        .collection('users')
        .doc(event.userId)
        .collection('monthly_stats')
        .doc(monthStr);

    final batch = _db.batch();

    // Registrar el evento con ID autogenerado
    batch.set(eventRef, event);

    // Incrementar el contador de deposiciones del usuario de por vida
    batch.update(userRef, {
      'poopCount': FieldValue.increment(1),
      'lastPoop': Timestamp.fromDate(event.timestamp),
    });

    // Incrementar estadísticas mensuales de forma atómica
    batch.set(monthlyStatsRef, {
      'count': FieldValue.increment(1),
      'estimatedWeight': FieldValue.increment(event.estimatedWeight),
      'month': monthStr,
    }, SetOptions(merge: true));

    await batch.commit();

    int kcoinsReward = 15;
    if (event.latitude != null) kcoinsReward += 10;
    if (event.difficulty >= 4) kcoinsReward += 5;
    if (event.notes != null && event.notes!.length > 20) kcoinsReward += 5;
    await addKcoins(event.userId, kcoinsReward);

    await _updateUserStreaks(event.userId, event.displayName, isDeletion: false, newEventDate: event.timestamp);
    await _updateActiveDuelsCount(event.userId);
    await _checkAndUnlockAchievements(event);
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

      await _updateUserStreaks(event.userId, event.displayName, isDeletion: true);
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

    await _updateUserStreaks(event.userId, event.displayName, isDeletion: true);
  }

  // Obtener flujo de eventos del usuario actual
  Stream<List<KKEvent>> getEvents(String userId) {
    if (useMockData) {
      Future.microtask(() => _eventsStreamController.add(List.from(_mockEvents)));
      return _eventsStreamController.stream;
    }
    return _eventsRef
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => doc.data()).toList());
  }

  // Obtener todos los eventos (para exportación CSV de admin o backup)
  Future<List<KKEvent>> getAllEvents() async {
    if (useMockData) {
      return List.from(_mockEvents);
    }
    final snapshot = await _eventsRef
        .orderBy('timestamp', descending: true)
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // --- PAGINACIÓN ---
  Future<PagedEventsResult> getEventsPaged(String userId, {int limit = 20, Object? cursor}) async {
    if (useMockData) {
      int startIndex = 0;
      if (cursor != null && cursor is String) {
        final idx = _mockEvents.indexWhere((e) => e.id == cursor);
        if (idx != -1) {
          startIndex = idx + 1;
        }
      }
      if (startIndex >= _mockEvents.length) {
        return PagedEventsResult(events: [], cursor: null, hasMore: false);
      }
      final endIndex = (startIndex + limit) > _mockEvents.length ? _mockEvents.length : (startIndex + limit);
      final events = _mockEvents.sublist(startIndex, endIndex);
      final hasMore = endIndex < _mockEvents.length;
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
              };
            }).toList());
  }

  // --- CHAT (COS) ---

  // Obtener flujo de mensajes de chat en tiempo real
  Stream<List<ChatMessage>> getChatMessages({int limit = 50}) {
    if (useMockData) {
      Future.microtask(() => _chatStreamController.add(List.from(_mockChatMessages)));
      return _chatStreamController.stream;
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
    await _chatRef.add(message);
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

    return _db.collection('typing').snapshots().map((snap) {
      final map = <String, String>{};
      for (var doc in snap.docs) {
        final data = doc.data();
        final timestamp = data['timestamp'] as Timestamp?;
        if (timestamp != null) {
          final diff = DateTime.now().difference(timestamp.toDate());
          if (diff.inSeconds < 8) {
            map[doc.id] = data['username'] ?? 'Usuario';
          }
        }
      }
      return map;
    });
  }

  // Recalcular y actualizar rachas en base de datos de forma incremental y O(1)
  Future<void> _updateUserStreaks(
    String userId,
    String? username, {
    bool isDeletion = false,
    DateTime? newEventDate,
  }) async {
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

      // Firestore real (Optimizado O(1))
      final userRef = _db.collection('users').doc(userId);
      int finalStreak = 0;
      int finalMaxStreak = 0;

      if (!isDeletion && newEventDate != null) {
        // Caso común: Agregar evento (Cálculo Incremental)
        final userSnap = await userRef.get();
        final data = userSnap.data();
        
        final currentStreak = data?['currentStreak'] as int? ?? 0;
        final maxStreak = data?['maxStreak'] as int? ?? 0;
        final lastPoopTimestamp = data?['lastPoop'] as Timestamp?;

        if (lastPoopTimestamp == null) {
          // Es su primera deposición
          finalStreak = 1;
        } else {
          final lastPoopDate = lastPoopTimestamp.toDate();
          
          // Calcular diferencia en días (ignorando horas)
          final todayMidnight = DateTime(newEventDate.year, newEventDate.month, newEventDate.day);
          final lastMidnight = DateTime(lastPoopDate.year, lastPoopDate.month, lastPoopDate.day);
          final differenceInDays = todayMidnight.difference(lastMidnight).inDays;

          if (differenceInDays == 0) {
            // Misma fecha del día, la racha se mantiene
            finalStreak = currentStreak == 0 ? 1 : currentStreak;
          } else if (differenceInDays == 1) {
            // El día siguiente, racha incrementada
            finalStreak = currentStreak + 1;
          } else {
            // Racha rota, se reinicia en 1
            finalStreak = 1;
          }
        }
        finalMaxStreak = finalStreak > maxStreak ? finalStreak : maxStreak;
      } else {
        // Caso raro: Borrado de evento
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
        finalStreak = KKEvent.calculateStreak(events);
        finalMaxStreak = finalStreak > currentMax ? finalStreak : currentMax;
      }

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
      return {
        'kcoins': kcoins,
        'equippedSkin': equippedSkin,
        'unlockedSkins': unlockedSkins,
        'equippedTitle': equippedTitle,
      };
    }
    
    final doc = await _db.collection('users').doc(userId).get();
    if (doc.exists) {
      final data = doc.data();
      return {
        'kcoins': data?['kcoins'] ?? 0,
        'equippedSkin': data?['equippedSkin'] ?? '💩',
        'unlockedSkins': List<String>.from(data?['unlockedSkins'] ?? ['💩']),
        'equippedTitle': data?['equippedTitle'],
      };
    }
    return {
      'kcoins': 0,
      'equippedSkin': '💩',
      'unlockedSkins': ['💩'],
      'equippedTitle': null,
    };
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
      
      final doc = await userRef.get();
      final newAmt = doc.data()?['kcoins'] as int? ?? 0;
      if (newAmt >= 500) {
        await unlockAchievement(userId, 'caca_capitalist', null);
      }
    } catch (e) {
      debugPrint('Error al agregar Kcoins: $e');
    }
  }

  Future<bool> buySkin(String userId, String skin, int cost) async {
    try {
      final profile = await getUserZenProfile(userId);
      final kcoins = profile['kcoins'] as int;
      final unlocked = List<String>.from(profile['unlockedSkins']);
      
      if (kcoins < cost || unlocked.contains(skin)) {
        return false;
      }
      
      if (useMockData) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('zen_kcoins_$userId', kcoins - cost);
        unlocked.add(skin);
        await prefs.setStringList('zen_unlocked_skins_$userId', unlocked);
        
        if (unlocked.length >= 3) {
          await unlockAchievement(userId, 'fashion_poop', null);
        }
        return true;
      }
      
      final userRef = _db.collection('users').doc(userId);
      await _db.runTransaction((transaction) async {
        transaction.update(userRef, {
          'kcoins': FieldValue.increment(-cost),
          'unlockedSkins': FieldValue.arrayUnion([skin]),
        });
      });
      
      if (unlocked.length + 1 >= 3) {
        await unlockAchievement(userId, 'fashion_poop', null);
      }
      return true;
    } catch (e) {
      debugPrint('Error al comprar skin: $e');
      return false;
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

  // Obtener flujo de duelos en curso del usuario actual
  Stream<List<Map<String, dynamic>>> getActiveDuels(String userId) {
    if (useMockData) {
      Future.microtask(() => _duelsStreamController.add(List.from(_mockDuels)));
      return _duelsStreamController.stream;
    }
    return _db
        .collection('duels')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                ...data,
                'startDate': (data['startDate'] as Timestamp?)?.toDate(),
                'endDate': (data['endDate'] as Timestamp?)?.toDate(),
              };
            }).toList());
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

  Future<void> _updateActiveDuelsCount(String userId) async {
    try {
      if (useMockData) {
        for (var d in _mockDuels) {
          if (d['status'] == 'active' && d['participants'].contains(userId)) {
            if (d['challengerId'] == userId) {
              d['challengerCount'] = (d['challengerCount'] as int) + 1;
            } else if (d['challengedId'] == userId) {
              d['challengedCount'] = (d['challengedCount'] as int) + 1;
            }

            final chCount = d['challengerCount'] as int;
            final cdCount = d['challengedCount'] as int;
            if (chCount >= 5 || cdCount >= 5) {
              d['status'] = 'finished';
              final winnerId = chCount > cdCount ? d['challengerId'] : d['challengedId'];
              final winnerName = chCount > cdCount ? d['challengerName'] : d['challengedName'];
              
              await unlockAchievement(winnerId, 'duelist', winnerName);

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
        if (endDate != null && endDate.isBefore(now)) {
          batch.update(doc.reference, {'status': 'finished'});
          
          final chCount = data['challengerCount'] as int? ?? 0;
          final cdCount = data['challengedCount'] as int? ?? 0;
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
        } else {
          if (data['challengerId'] == userId) {
            batch.update(doc.reference, {'challengerCount': FieldValue.increment(1)});
          } else if (data['challengedId'] == userId) {
            batch.update(doc.reference, {'challengedCount': FieldValue.increment(1)});
          }
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

  Future<void> deleteAllUserData(String uid) async {
    if (useMockData) {
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
      return;
    }

    // En producción (Firestore):
    final batch = _db.batch();

    // 1. Obtener y eliminar todos los documentos en 'events' donde userId == uid
    final eventsQuery = await _db.collection('events').where('userId', isEqualTo: uid).get();
    for (var doc in eventsQuery.docs) {
      batch.delete(doc.reference);
    }

    // 2. Obtener y eliminar todas las estadísticas mensuales del usuario
    final monthlyStatsQuery = await _db
        .collection('users')
        .doc(uid)
        .collection('monthly_stats')
        .get();
    for (var doc in monthlyStatsQuery.docs) {
      batch.delete(doc.reference);
    }

    // 3. Eliminar documento principal del usuario
    batch.delete(_db.collection('users').doc(uid));

    // 4. Eliminar estadísticas de racha, zen_profiles, logros (si existieran colecciones raíz dedicadas)
    batch.delete(_db.collection('streaks').doc(uid));
    batch.delete(_db.collection('zen_profiles').doc(uid));
    batch.delete(_db.collection('achievements').doc(uid));

    await batch.commit();
  }

  Future<void> importBackupEvents(String uid, String username, List<KKEvent> events) async {
    if (useMockData) {
      // 1. Eliminar eventos antiguos de mock del usuario
      _mockEvents.removeWhere((e) => e.userId == uid);
      
      // 2. Insertar todos los nuevos eventos
      final rand = Random();
      for (var ev in events) {
        // Sobreescribir userId y username por seguridad
        final securedEvent = KKEvent(
          id: ev.id.isEmpty ? 'mock_${DateTime.now().millisecondsSinceEpoch}_${rand.nextInt(10000)}' : ev.id,
          userId: uid,
          displayName: username,
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
    // 1. Borrar eventos antiguos del usuario
    final eventsQuery = await _db.collection('events').where('userId', isEqualTo: uid).get();
    final deleteBatch = _db.batch();
    for (var doc in eventsQuery.docs) {
      deleteBatch.delete(doc.reference);
    }
    await deleteBatch.commit();

    // 2. Insertar los nuevos eventos en lotes de máximo 500 documentos por batch
    int index = 0;
    while (index < events.length) {
      final batch = _db.batch();
      final chunk = events.skip(index).take(500);
      for (var ev in chunk) {
        final securedEvent = KKEvent(
          id: ev.id.isEmpty ? _db.collection('events').doc().id : ev.id,
          userId: uid,
          displayName: username,
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
    final deleteMonthlyBatch = _db.batch();
    for (var doc in monthlyStatsQuery.docs) {
      deleteMonthlyBatch.delete(doc.reference);
    }
    await deleteMonthlyBatch.commit();

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
    
    // 4. Actualizar contador total de poopCount en users/{uid}
    final userRef = _db.collection('users').doc(uid);
    DateTime? lastPoopTime;
    if (events.isNotEmpty) {
      lastPoopTime = events.map((e) => e.timestamp).reduce((a, b) => a.isAfter(b) ? a : b);
    }
    statsBatch.update(userRef, {
      'poopCount': events.length,
      if (lastPoopTime != null) 'lastPoop': Timestamp.fromDate(lastPoopTime),
    });

    await statsBatch.commit();
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
