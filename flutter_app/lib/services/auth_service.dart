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

    // 1. Verificar si la colección de usuarios está vacía (primer registro = admin)
    final usersSnapshot = await _db.collection('users').limit(1).get();
    final bool isFirstUser = usersSnapshot.docs.isEmpty;

    String role = 'user';
    if (!isFirstUser) {
      // 2. Temporalmente desactivamos la lista blanca para permitir libre registro
      /*
      final authDoc = await _db.collection('authorized_emails').doc(cleanEmail).get();
      if (!authDoc.exists) {
        throw Exception('Este correo electrónico no está autorizado en esta aplicación privada. Pídele al administrador que te añada.');
      }
      final authData = authDoc.data();
      role = authData?['role'] ?? 'user';
      */
      role = 'user'; // Asignamos rol básico por defecto
    } else {
      role = 'admin';
    }

    try {
      // 3. Crear el usuario en Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      // 4. Actualizar displayName en Firebase Auth
      await userCredential.user?.updateDisplayName(username);

      // 5. Crear documento de usuario en Firestore con su rol
      await _db.collection('users').doc(userCredential.user!.uid).set({
        'username': username,
        'email': cleanEmail,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 6. Marcar como registrado en la lista blanca si no es el primer usuario
      /*
      if (!isFirstUser) {
        await _db.collection('authorized_emails').doc(cleanEmail).update({'registered': true});
      }
      */

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(_translateAuthError(e.code));
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

    // Subir imagen si existe
    if (avatarImage != null) {
      final ref = FirebaseStorage.instance.ref().child('avatars/${user.uid}.jpg');
      await ref.putFile(avatarImage);
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

    // Actualizar email via verification (recomendado) o directo si lo soporta
    try {
      await user.verifyBeforeUpdateEmail(newEmail);
    } catch (e) {
      // Intento por método anterior si no soporta verifyBeforeUpdateEmail
      // ignore: deprecated_member_use
      await user.updateEmail(newEmail);
    }

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
