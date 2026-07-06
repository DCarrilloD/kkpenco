import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
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
      displayName: user.displayName ?? 'Sin Nombre',
      photoURL: user.photoURL,
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
      final email = _mockCurrentUser?.email ?? 'mock@kkpenco.com';
      final bool isMockAdmin = email.contains('admin') || uid == 'mock_uid';
      return {
        'username': _mockCurrentUser?.displayName ?? 'Admin Mock',
        'email': email,
        'role': isMockAdmin ? 'admin' : 'user',
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

    final cleanEmail = email.trim().toLowerCase();

    // El rol siempre se crea como 'user': las reglas de Firestore rechazan crear
    // el documento con role:'admin' (ver firestore.rules), así que el admin de un
    // despliegue nuevo se eleva manualmente desde la consola. Antes se intentaba
    // 'admin' para el primer usuario, lo que hacía fallar su propio registro.
    // (La lista blanca sigue desactivada; si se reactiva, habrá que repensar la
    // lectura previa al registro.)
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      await userCredential.user?.updateDisplayName(username);

      await _db.collection('users').doc(userCredential.user!.uid).set({
        'username': username,
        'email': cleanEmail,
        'role': 'user',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(_translateAuthError(e.code));
    } catch (e) {
      // Errores de red o de Firestore: mensaje amable en vez del crudo.
      throw Exception('No se pudo completar el registro. Revisa tu conexión e inténtalo de nuevo.');
    }
  }

  // Iniciar sesión
  Future<dynamic> signIn({
    required String email,
    required String password,
  }) async {
    if (useMockData) {
      final String uid = email.contains('admin') ? 'mock_uid' : '${email.split('@')[0]}_uid';
      _mockCurrentUser = AppUser(
        uid: uid,
        displayName: email.split('@')[0],
        photoURL: null,
        email: email,
      );
      _mockUserStreamController.add(_mockCurrentUser); // Emitimos el usuario simulado
      return true;
    }
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(_translateAuthError(e.code));
    }
  }

  String _translateAuthError(String code) {
    switch (code) {
      case 'weak-password':
        return 'La contraseña proporcionada es demasiado débil.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta para ese correo electrónico.';
      case 'user-not-found':
        return 'No se encontró ningún usuario con ese correo electrónico.';
      case 'wrong-password':
        return 'La contraseña proporcionada es incorrecta.';
      case 'invalid-email':
        return 'El formato del correo electrónico no es válido.';
      case 'invalid-credential':
        return 'Credenciales inválidas. Verifica tu correo y contraseña.';
      default:
        return 'Ocurrió un error de autenticación. Código: $code';
    }
  }


  // Actualizar perfil (Nombre y Foto)
  Future<void> updateProfile({String? displayName, File? avatarImage}) async {
    if (useMockData) return;

    final user = _auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado.');

    String? photoUrl = user.photoURL;

    // Subir imagen si existe. Fijamos contentType explícito para que las reglas
    // de Storage (que exigen image/*) acepten la subida aunque el archivo del
    // picker venga como heic/octet-stream.
    if (avatarImage != null) {
      final ref = FirebaseStorage.instance.ref().child('avatars/${user.uid}.jpg');
      await ref.putFile(avatarImage, SettableMetadata(contentType: 'image/jpeg'));
      photoUrl = await ref.getDownloadURL();
    }

    // Actualizar Firebase Auth
    if (displayName != null) {
      await user.updateDisplayName(displayName);
    }
    if (avatarImage != null) {
      await user.updatePhotoURL(photoUrl);
    }

    // Actualizar Firestore
    final updateData = <String, dynamic>{};
    if (displayName != null) updateData['username'] = displayName;
    if (photoUrl != null) updateData['photoURL'] = photoUrl;

    if (updateData.isNotEmpty) {
      await _db.collection('users').doc(user.uid).set(updateData, SetOptions(merge: true));
    }
    
    // Forzar actualización del stream local (Auth reload)
    await user.reload();
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
  // Cambiar Email
  Future<void> changeEmail({
    required String currentPassword,
    required String newEmail,
  }) async {
    if (useMockData) {
      return;
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

    // Actualizar email vía verificación: Firebase envía un correo de confirmación
    // al nuevo email y el cambio se aplica al pulsar el enlace.
    // (firebase_auth 6 eliminó el antiguo updateEmail directo; ya no hay fallback.)
    await user.verifyBeforeUpdateEmail(newEmail);

    // Actualizar también en firestore
    await _db.collection('users').doc(user.uid).update({'email': newEmail.trim().toLowerCase()});
  }

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
