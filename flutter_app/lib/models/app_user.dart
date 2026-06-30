import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String displayName;
  final String? photoURL;
  final String? email;
  final String role;
  final int poopCount;
  final DateTime? lastPoop;
  final int photoCount;
  final int reactionsCount;
  final int currentStreak;
  final int maxStreak;
  final int kcoins;

  AppUser({
    required this.uid,
    required this.displayName,
    this.photoURL,
    this.email,
    this.role = 'user',
    this.poopCount = 0,
    this.lastPoop,
    this.photoCount = 0,
    this.reactionsCount = 0,
    this.currentStreak = 0,
    this.maxStreak = 0,
    this.kcoins = 0,
  });

  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null) {
      throw Exception("User data is null");
    }
    return AppUser(
      uid: snapshot.id,
      displayName: data['username'] as String? ?? 'Sin Nombre',
      photoURL: data['photoURL'] as String?,
      email: data['email'] as String?,
      role: data['role'] as String? ?? 'user',
      poopCount: data['poopCount'] as int? ?? 0,
      lastPoop: data['lastPoop'] != null ? (data['lastPoop'] as Timestamp).toDate() : null,
      photoCount: data['photoCount'] as int? ?? 0,
      reactionsCount: data['reactionsCount'] as int? ?? 0,
      currentStreak: data['currentStreak'] as int? ?? 0,
      maxStreak: data['maxStreak'] as int? ?? 0,
      kcoins: data['kcoins'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'username': displayName,
      if (photoURL != null) 'photoURL': photoURL,
      'role': role,
      'poopCount': poopCount,
      'photoCount': photoCount,
      'reactionsCount': reactionsCount,
      'currentStreak': currentStreak,
      'maxStreak': maxStreak,
      'kcoins': kcoins,
    };
    if (email != null) map['email'] = email;
    if (lastPoop != null) map['lastPoop'] = Timestamp.fromDate(lastPoop!);
    return map;
  }
}
