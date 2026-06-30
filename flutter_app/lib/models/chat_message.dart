import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String userId;
  final String displayName;
  final String content;
  final DateTime timestamp;
  final String type; // 'text', 'share_poop', 'image', 'game_challenge'
  final Map<String, List<String>> reactions; // emoji -> list of userIds
  final Map<String, dynamic>? metadata; // Para guardar datos del evento compartido o url de foto

  ChatMessage({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.content,
    required this.timestamp,
    this.type = 'text',
    this.reactions = const {},
    this.metadata,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final reactionsData = data['reactions'] as Map<String, dynamic>? ?? {};
    final reactionsMap = Map<String, List<String>>.from(
      reactionsData.map(
        (key, value) => MapEntry(
          key,
          List<String>.from(value is List ? value : []),
        ),
      ),
    );

    return ChatMessage(
      id: doc.id,
      userId: data['userId'] ?? '',
      displayName: data['username'] as String? ?? 'Desconocido',
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      type: data['type'] ?? 'text',
      reactions: reactionsMap,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'username': displayName,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': type,
      'reactions': reactions.map((key, value) => MapEntry(key, value)),
      if (metadata != null) 'metadata': metadata,
    };
  }
}
