---
name: firebase-firestore-standard
description: Directrices técnicas de optimización, modelado y consultas para Cloud Firestore en Flutter.
---

# Habilidad: firebase-firestore-standard

Esta habilidad proporciona directrices estrictas y patrones de diseño optimizados para interactuar con Cloud Firestore en aplicaciones Flutter. Evita el uso de librerías obsoletas y asegura el mejor rendimiento y control de cuotas (lecturas/escrituras).

## 1. Modelado de Datos Robusto

Toda interacción con documentos de Firestore debe realizarse mediante clases de datos fuertemente tipadas en Dart. Queda prohibido el uso directo de `Map<String, dynamic>` en la capa de interfaz de usuario.

### Estructura de Modelo Recomendada
```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String id;
  final String email;
  final String displayName;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    required this.createdAt,
  });

  // Convertir de Firestore DocumentSnapshot
  factory UserProfile.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data();
    return UserProfile(
      id: snapshot.id,
      email: data?['email'] ?? '',
      displayName: data?['displayName'] ?? '',
      createdAt: (data?['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Convertir a Mapa para Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
```

## 2. Acceso e Inicialización con Colecciones Tipadas
Utiliza siempre `.withConverter` en las referencias de colección para asegurar el tipado de los datos a nivel de compilación y evitar errores de conversión en tiempo de ejecución.

```dart
CollectionReference<UserProfile> getUsersCollection() {
  return FirebaseFirestore.instance
      .collection('users')
      .withConverter<UserProfile>(
        fromFirestore: UserProfile.fromFirestore,
        toFirestore: (user, _) => user.toFirestore(),
      );
}
```

## 3. Optimización de Consultas (Control de Costos)

Para evitar el consumo excesivo de operaciones de lectura y optimizar la velocidad de la app:
- **Límites de consulta**: Utiliza siempre `.limit(n)` en listas largas o consultas iniciales para evitar descargar cientos de documentos innecesariamente.
- **Uso de índices**: Asegúrate de que las consultas complejas con múltiples filtros (`where`) y ordenamientos (`orderBy`) tengan definidos sus correspondientes índices en `firestore.indexes.json`.
- **Escuchas activas vs Lecturas puntuales**: Usa `.get()` para operaciones de lectura única. Reserva `.snapshots()` (Streams) estrictamente para pantallas que requieran reactividad en tiempo real (por ejemplo, chats en vivo).

### Ejemplo de consulta optimizada y paginada:
```dart
Query<UserProfile> query = getUsersCollection()
    .orderBy('createdAt', descending: true)
    .limit(20);

// Para paginar, usa el último documento obtenido como cursor:
QuerySnapshot<UserProfile> snapshot = await query.get();
if (snapshot.docs.isNotEmpty) {
  var lastDoc = snapshot.docs.last;
  Query<UserProfile> nextQuery = query.startAfterDocument(lastDoc);
}
```

## 4. Manejo Seguro de Excepciones

Las operaciones de red con Firestore deben envolverse en bloques `try-catch` capturando específicamente `FirebaseException` para proporcionar retroalimentación adecuada al usuario:

```dart
try {
  await getUsersCollection().doc(userId).set(userProfile);
} on FirebaseException catch (e) {
  // Manejo estructurado del error
  print('Error de Firestore (${e.code}): ${e.message}');
  rethrow;
} catch (e) {
  print('Error inesperado: $e');
  rethrow;
}
```
