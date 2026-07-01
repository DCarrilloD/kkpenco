---
name: firebase-auth-basics
description: Directrices para el control de autenticación de usuarios y escucha de estado con Firebase Auth en Flutter.
---

# Habilidad: firebase-auth-basics

Esta habilidad proporciona directrices y estándares para la implementación de flujos de autenticación seguros y el manejo robusto del estado del usuario utilizando `firebase_auth` en Flutter.

## 1. Escucha Reactiva del Estado de Autenticación

El estado del usuario (autenticado, no autenticado, cargando) debe manejarse de forma reactiva escuchando el flujo `authStateChanges()`. No almacenes el estado del usuario de forma estática en variables locales sin sincronizarlo con el flujo de Firebase.

### Ejemplo de Enrutamiento o Switch de Pantallas
```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const HomeScreen(); // Usuario autenticado
        }
        return const LoginScreen(); // Usuario no autenticado
      }
    );
  }
}
```

## 2. Flujo de Autenticación Seguro

### Registro con Correo y Contraseña
```dart
Future<UserCredential?> signUpWithEmail({
  required String email,
  required String password,
}) async {
  try {
    return await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  } on FirebaseAuthException catch (e) {
    _handleAuthError(e);
    rethrow;
  }
}
```

### Inicio de Sesión
```dart
Future<UserCredential?> signInWithEmail({
  required String email,
  required String password,
}) async {
  try {
    return await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  } on FirebaseAuthException catch (e) {
    _handleAuthError(e);
    rethrow;
  }
}
```

## 3. Manejo de Errores de FirebaseAuthException

Debes capturar y gestionar explícitamente los códigos de error comunes para proporcionar mensajes en español claros al usuario en lugar de mostrar los códigos técnicos en bruto.

```dart
void _handleAuthError(FirebaseAuthException e) {
  switch (e.code) {
    case 'weak-password':
      print('La contraseña proporcionada es demasiado débil.');
      break;
    case 'email-already-in-use':
      print('Ya existe una cuenta para ese correo electrónico.');
      break;
    case 'user-not-found':
      print('No se encontró ningún usuario con ese correo electrónico.');
      break;
    case 'wrong-password':
      print('La contraseña proporcionada es incorrecta.');
      break;
    case 'invalid-email':
      print('El formato del correo electrónico no es válido.');
      break;
    default:
      print('Ocurrió un error de autenticación: ${e.message}');
  }
}
```

## 4. Cierre de Sesión Seguro
Siempre limpia cualquier caché o estado de la aplicación local al cerrar sesión:

```dart
Future<void> signOut() async {
  await FirebaseAuth.instance.signOut();
}
```
