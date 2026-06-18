import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_user.dart';

// Bandera global para simulación en plataformas no configuradas
bool useMockData = false;

class AuthService {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // Controlador de stream para el estado mock de autenticación
  static final _mockUserStreamController = StreamController<AppUser?>.broadcast();
  static AppUser? _mockCurrentUser;

  // Mapear el usuario de Firebase a AppUser
  AppUser? _mapFirebaseUser(User? user) {
    if (user == null) return null;
    return AppUser(
      uid: user.uid,
      displayName: user.displayName,
      email: user.email,
    );
  }

  // Stream para escuchar el estado de autenticación
  Stream<AppUser?> get userChanges {
    if (useMockData) {
      // Enviamos el usuario simulado inicialmente
      Future.microtask(() => _mockUserStreamController.add(_mockCurrentUser));
      return _mockUserStreamController.stream;
    }
    return _auth.authStateChanges().map(_mapFirebaseUser);
  }

  // Obtener usuario actual
  AppUser? get currentUser {
    if (useMockData) {
      return _mockCurrentUser;
    }
    return _mapFirebaseUser(_auth.currentUser);
  }

  // Obtener datos del perfil de usuario desde Firestore
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    if (useMockData) {
      return {
        'username': _mockCurrentUser?.displayName ?? 'Admin Mock',
        'email': _mockCurrentUser?.email ?? 'mock@kkpenco.com',
      };
    }
    try {
      final doc = await _db.collection('users').doc(uid).get();
      return doc.data();
    } catch (e) {
      debugPrint('Error al obtener perfil de usuario: $e');
      return null;
    }
  }

  // Registro
  Future<dynamic> signUp({
    required String username,
    required String email,
    required String password,
  }) async {
    if (useMockData) {
      throw Exception('El registro no está disponible en modo simulación. Inicia sesión como Invitado (cualquier email/pass).');
    }

    // 1. Crear el usuario en Firebase Auth
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // 2. Actualizar displayName en Firebase Auth
    await userCredential.user?.updateDisplayName(username);

    // 3. Crear documento de usuario en Firestore
    await _db.collection('users').doc(userCredential.user!.uid).set({
      'username': username,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return userCredential;
  }

  // Iniciar sesión
  Future<dynamic> signIn({
    required String email,
    required String password,
  }) async {
    if (useMockData) {
      _mockCurrentUser = AppUser(
        uid: 'mock_uid',
        displayName: email.split('@')[0],
        email: email,
      );
      _mockUserStreamController.add(_mockCurrentUser); // Emitimos el usuario simulado
      return true;
    }
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return userCredential;
  }

  // Cerrar sesión
  Future<void> signOut() async {
    if (useMockData) {
      _mockCurrentUser = null;
      _mockUserStreamController.add(null);
      return;
    }
    await _auth.signOut();
  }

  // Cambiar contraseña
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (useMockData) {
      return; // Éxito inmediato en simulación
    }
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('Usuario no autenticado.');
    }

    // Reautenticar al usuario
    final cred = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(cred);

    // Actualizar contraseña
    await user.updatePassword(newPassword);
  }

  Future<void> reauthenticate(String password) async {
    if (useMockData) {
      return;
    }
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('Usuario no autenticado.');
    }
    final cred = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );
    await user.reauthenticateWithCredential(cred);
  }

  // Eliminar cuenta de Firebase Auth tras reautenticar
  Future<void> deleteAccount(String password) async {
    if (useMockData) {
      _mockCurrentUser = null;
      _mockUserStreamController.add(null);
      return;
    }
    
    // 1. Reautenticar
    await reauthenticate(password);

    // 2. Eliminar de Firebase Auth
    final user = _auth.currentUser;
    if (user != null) {
      await user.delete();
    }
  }

  // Gestión de biometría
  static const String _biometricPrefKey = 'biometrics_enabled';

  Future<bool> isBiometricEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_biometricPrefKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_biometricPrefKey, enabled);
    } catch (_) {}
  }
}
