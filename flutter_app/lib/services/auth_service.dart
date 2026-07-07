import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
      case 'account-exists-with-different-credential':
        return 'Ya existe una cuenta con ese correo pero con otro método de acceso.';
      default:
        return 'Ocurrió un error de autenticación. Código: $code';
    }
  }

  // --- GOOGLE SIGN-IN (OAuth) ---

  // initialize() de google_sign_in debe llamarse una sola vez por sesión de
  // app; el Future compartido evita dobles inicializaciones. En Android el
  // serverClientId sale del recurso default_web_client_id que genera el
  // plugin de google-services desde google-services.json.
  static Future<void>? _googleInitFuture;

  Future<void> _ensureGoogleInitialized() {
    return _googleInitFuture ??= GoogleSignIn.instance.initialize();
  }

  /// Inicia sesión con Google. Devuelve `false` si el usuario cerró el
  /// selector de cuentas (no es un error); lanza [Exception] con mensaje
  /// amable en los fallos reales.
  Future<bool> signInWithGoogle() async {
    if (useMockData) {
      // El botón está oculto en mock (Windows no soporta google_sign_in);
      // esto es solo un cinturón de seguridad.
      throw Exception('Google Sign-In no está disponible en modo simulación.');
    }

    try {
      await _ensureGoogleInitialized();
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw Exception('Google no devolvió una credencial válida. Inténtalo de nuevo.');
      }

      final userCredential = await _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );

      // Con OAuth no se pasa por signUp: crear el doc de `users` la primera
      // vez (las reglas permiten crear el propio doc con rol 'user').
      await _ensureUserDocument(userCredential.user);
      return true;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return false;
      }
      debugPrint('GoogleSignInException: ${e.code} ${e.description}');
      throw Exception('No se pudo iniciar sesión con Google. Inténtalo de nuevo.');
    } on FirebaseAuthException catch (e) {
      throw Exception(_translateAuthError(e.code));
    }
  }

  // Crea el documento de usuario si no existe (primer acceso por OAuth).
  Future<void> _ensureUserDocument(User? user) async {
    if (user == null) return;
    try {
      final docRef = _db.collection('users').doc(user.uid);
      final doc = await docRef.get();
      if (doc.exists) return;

      final fallbackName = user.email?.split('@').first ?? 'Sin Nombre';
      await docRef.set({
        'username': user.displayName ?? fallbackName,
        'email': user.email?.trim().toLowerCase(),
        'role': 'user',
        if (user.photoURL != null) 'photoURL': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // La sesión ya está iniciada; si esta escritura falla (p. ej. red), no
      // se aborta el login. El email se reconcilia al arrancar de todos modos.
      debugPrint('Error creando el documento de usuario: $e');
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
    // Si se entró con Google, cerrar también esa sesión: si no, el próximo
    // login reutiliza la cuenta anterior sin mostrar el selector.
    if (_googleInitFuture != null) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (e) {
        debugPrint('Error cerrando la sesión de Google: $e');
      }
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
    // Firestore NO se toca aquí: el cambio solo es real cuando el usuario pulsa
    // el enlace; la copia se reconcilia en syncEmailWithFirestore() al arrancar.
    await user.verifyBeforeUpdateEmail(newEmail);
  }

  /// Reconcilia la copia del email en Firestore con el de Auth (fuente de
  /// verdad). Se llama al arrancar con sesión: cubre el caso de un cambio de
  /// email confirmado por enlace después de que la app se cerrara.
  Future<void> syncEmailWithFirestore() async {
    if (useMockData) return;
    try {
      final user = _auth.currentUser;
      final authEmail = user?.email?.trim().toLowerCase();
      if (user == null || authEmail == null) return;

      final docRef = _db.collection('users').doc(user.uid);
      final doc = await docRef.get();
      if (doc.exists && doc.data()?['email'] != authEmail) {
        await docRef.update({'email': authEmail});
      }
    } catch (e) {
      // Reconciliación en segundo plano: sin conexión se reintentará en el
      // próximo arranque.
      debugPrint('Error sincronizando email con Firestore: $e');
    }
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

  // Eliminar cuenta de Firebase Auth tras reautenticar (solo modo simulación;
  // en producción el borrado completo lo hace deleteMyAccountRemote)
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

  /// Autodestrucción real de la cuenta vía Cloud Function `deleteMyAccount`.
  /// El borrado debe ser server-side (Admin SDK): las reglas de Firestore no
  /// permiten al dueño borrar su doc de `users` ni sus eventos de más de 5
  /// minutos, así que el antiguo batch de cliente fallaba siempre. La función
  /// borra eventos + monthly_stats + doc de usuario + Storage y, al final, el
  /// usuario de Auth. Aquí solo se reautentica, se llama y se cierra la
  /// sesión local (el usuario ya no existe en el servidor).
  Future<void> deleteMyAccountRemote(String password) async {
    await reauthenticate(password);

    try {
      await FirebaseFunctions.instance
          .httpsCallable('deleteMyAccount')
          .call();
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'No se pudo completar el borrado de la cuenta.');
    }

    // El usuario de Auth ya no existe en el servidor: cerrar la sesión local
    // para que authStateChanges lleve de vuelta a la pantalla de login.
    await _auth.signOut();
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
