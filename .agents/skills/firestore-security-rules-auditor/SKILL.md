---
name: firestore-security-rules-auditor
description: Directrices de auditoría estática para validar reglas de seguridad en firestore.rules.
---

# Habilidad: firestore-security-rules-auditor

Esta habilidad proporciona directrices rigurosas de seguridad para auditar, escribir y estructurar las reglas de seguridad en `firestore.rules`. El objetivo es prevenir accesos no autorizados y mitigar filtraciones de información sensible en Firestore.

## 1. Reglas Prohibidas e Inseguras

Queda estrictamente prohibido utilizar reglas de lectura y escritura universales desprotegidas en producción. Cualquier configuración como la siguiente fallará la auditoría de seguridad:

```javascript
// INSEGURO - PROHIBIDO
match /{document=**} {
  allow read, write: if true;
}
```

## 2. Estructuración Segura de Reglas

Las reglas deben estructurarse de acuerdo con el principio de menor privilegio. A continuación se presentan las plantillas de seguridad recomendadas para el proyecto.

### Regla para Colecciones Privadas del Usuario (e.g., Perfiles, Ajustes)
El usuario solo debe poder leer y escribir sus propios datos. Su identificador único (`request.auth.uid`) debe coincidir con el identificador del documento (`userId`).

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Regla para la colección de usuarios
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### Regla para Colecciones con Campo de Propietario (`owner` o `userId`)
Si el documento tiene un campo que indica el creador del registro:

```javascript
match /todos/{todoId} {
  allow read, create: if request.auth != null;
  allow update, delete: if request.auth != null && resource.data.userId == request.auth.uid;
}
```

## 3. Lista de Verificación para Auditorías Estáticas

Al revisar o crear reglas de seguridad, el agente debe verificar:
1. **¿Se valida la autenticación?**: Todas las reglas de escritura deben validar `request.auth != null` a menos que sea un flujo de registro anónimo muy específico y controlado.
2. **¿Existe protección contra borrados accidentales?**: Restringe la operación `delete` solo a administradores o al propietario absoluto del registro.
3. **¿Se validan los tipos y estructuras de datos entrantes?**: Utiliza `request.resource.data` para verificar que el contenido nuevo cumpla con el formato esperado antes de permitir la escritura.

```javascript
// Ejemplo de validación de estructura de datos en la regla
match /posts/{postId} {
  allow create: if request.auth != null 
                && request.resource.data.title is string 
                && request.resource.data.title.size() > 0;
}
```
