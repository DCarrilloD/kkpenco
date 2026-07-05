# Plan de mejoras KKpenco

> Auditoría realizada el 2026-07-03 sobre conectividad, eficiencia de batería y posibles fallos.
> Orden sugerido de implementación: **1.1 → 1.2 → 3.1 → 2.3 → 2.4 → 1.3 → 2.2 → 2.1 → 1.4 → resto**.

**Recordatorios transversales** (de CLAUDE.md):
- Cada cambio en la capa de datos necesita **ambas ramas: Firestore y mock** (`useMockData`), o se rompen Windows y los tests.
- Los cambios de reglas se despliegan aparte: `firebase deploy --only firestore:rules`.

---

## Fase 1 — Bugs que rompen funcionalidad en producción (prioridad máxima)

### [x] 1.1 Las rachas nunca incrementan con Firebase real 🔴 — HECHO (2026-07-05)
- **Dónde**: `flutter_app/lib/services/database_service.dart:324` (batch en `addEvent`) y `:896-916` (`_updateUserStreaks`).
- **Problema**: el batch escribe `lastPoop = timestamp del nuevo evento` **antes** de llamar a `_updateUserStreaks`, que luego lee ese mismo `lastPoop` para comparar días. La diferencia de días siempre es 0 → la racha se queda congelada para siempre. En modo mock no se nota porque recalcula desde la lista completa.
- **Fix**: leer el `lastPoop` previo antes del `batch.commit()` (o calcular la racha dentro del propio batch) y pasar el valor antiguo a `_updateUserStreaks`.
- **Esfuerzo**: pequeño. **Test**: añadir caso en `test/` con eventos en días consecutivos.

### [x] 1.2 Reglas de Firestore desincronizadas con el cliente 🔴 — HECHO (2026-07-05, reglas e índices desplegados)
- **Dónde**: `flutter_app/firestore.rules`.
- **Problemas**:
  - `duels` **no tiene reglas** → denegado por defecto → duelos y nudges (`getActiveDuels`, `sendDuelChallenge`, `acceptDuelChallenge`) fallan en producción.
  - Borrar tu propio mensaje de chat: el cliente lo permite (`database_service.dart:636`), pero las reglas solo dejan borrar a admins (`firestore.rules:51`).
  - Mensajes de sistema: `shareAchievementToChat` escribe con `userId: 'system'`, pero las reglas exigen `userId == request.auth.uid` → los anuncios de logros al chat fallan siempre.
  - `authorized_emails` sin reglas → el panel admin de la whitelist no funciona en producción.
- **Fix**: actualizar reglas (duelos con validación de participantes, delete de chat por dueño, mensajes de sistema con campo firmado o Cloud Function, `authorized_emails` solo-admin) y desplegar.
- **Esfuerzo**: medio.

### [ ] 1.3 Las fotos del chat solo las ve quien las envía 🔴
- **Dónde**: `flutter_app/lib/screens/chat_screen.dart:133` (`_sendImage`) y `database_service.dart` (`sendChatMessage`).
- **Problema**: se guarda `image.path` (ruta local del dispositivo) en Firestore y nunca se sube el archivo. Los demás usuarios ven imagen rota. `firebase_storage` ya está en `pubspec.yaml` pero no se usa aquí.
- **Fix**: subir a Firebase Storage en la rama Firebase de `sendChatMessage`, guardar la URL de descarga; mantener ruta local en la rama mock. Añadir reglas de Storage.
- **Esfuerzo**: medio.

### [ ] 1.4 Notificaciones push muertas 🔴
- **Dónde**: `flutter_app/lib/services/push_notification_service.dart`, `main.dart`.
- **Problema**: `PushNotificationService.init()` no se llama desde ningún sitio: no se pide permiso, el token FCM no se guarda, `onBackgroundMessage` no se registra en `main()`. La notificación local del widget (`interactiveCallback`) falla silenciosamente en Android 13+ sin permiso runtime.
- **Fix**: llamar a `init()` tras el login, guardar token en `users/{uid}` con `onTokenRefresh`, registrar handler de background en `main()`, pedir permiso runtime de notificaciones.
- **Esfuerzo**: medio.

---

## Fase 2 — Eficiencia de batería, datos y coste Firestore

### [ ] 2.1 Cada registro descarga la colección `events` ENTERA 🔴💰
- **Dónde**: `database_service.dart:1599` (`_checkAndUnlockAchievements` → `getAllEvents()` sin límite) y `:1244` (`unlockAchievement` relee el doc de usuario en cada una de sus ~25 posibles llamadas).
- **Problema**: todos los eventos de todos los usuarios, en cada guardado (también desde el widget en background). Mayor consumidor de red/batería/lecturas facturables; crece sin tope.
- **Fix**: contadores agregados en el doc del usuario (cacas nocturnas, por localización, coordenadas distintas…) actualizados con `FieldValue.increment` en el mismo batch del evento; evaluar logros contra esos contadores. Pasar la lista de logros ya leída para evitar relecturas.
- **Esfuerzo**: grande, pero es la mejora con más retorno.

### [ ] 2.2 Guardado offline se cuelga con spinner infinito 🟠
- **Dónde**: `database_service.dart:243-347` (`addEvent`), `tracker_screen.dart` (`_saveEvent`).
- **Problema**: con `persistenceEnabled: true`, `await batch.commit()` no resuelve hasta el ack del servidor → sin conexión la UI queda bloqueada aunque la escritura ya esté encolada. Además `addEvent` encadena 4-5 round-trips secuenciales (`addKcoins`, rachas, duelos, logros).
- **Fix**: escritura optimista (no esperar el ack), fusionar `addKcoins` en el batch principal, ejecutar la lógica secundaria sin bloquear la UI.
- **Esfuerzo**: medio.

### [x] 2.3 Modo Juanito: música y timer siguen activos en background 🟠 — HECHO (2026-07-05)
- **Dónde**: `flutter_app/lib/screens/juanito_mode_screen.dart:80` (Timer 1s + setState de toda la pantalla) y `:225` (`AudioPlayer` en `ReleaseMode.loop`).
- **Problema**: sin `WidgetsBindingObserver`, la música zen sigue sonando con la app en segundo plano; el timer reconstruye la pantalla completa cada segundo, incluso con un minijuego activo.
- **Fix**: añadir observer de ciclo de vida (pausar música/timer en `paused`, reanudar en `resumed`); aislar el reloj en un widget propio con `ValueNotifier`.
- **Esfuerzo**: pequeño.

### [x] 2.4 Cronómetro del tracker pierde tiempo en background 🟠 — HECHO (2026-07-05)
- **Dónde**: `tracker_screen.dart:105-123` (`didChangeAppLifecycleState`).
- **Problema**: al ir a background cancela el timer (bien para batería), pero al volver continúa desde el mismo segundo: el tiempo con la pantalla apagada se pierde — justo el caso de uso principal 💩.
- **Fix**: guardar `DateTime` de inicio y derivar `_stopwatchSeconds` de `DateTime.now().difference(inicio)` al reanudar.
- **Esfuerzo**: pequeño.

### [ ] 2.5 GPS automático en cada arranque 🟡
- **Dónde**: `tracker_screen.dart:76-93` (`_loadAutoGeolocatePreference`).
- **Fix**: probar primero `Geolocator.getLastKnownPosition()` (coste cero) y solo pedir posición fresca al guardar el evento.

### [ ] 2.6 `stats_panel_screen` descarga todos los eventos sin límite 🟡
- **Dónde**: `flutter_app/lib/screens/stats_panel_screen.dart:91`.
- **Nota**: los exports CSV/JSON de `profile_screen.dart:363,419` sí necesitan todo legítimamente.
- **Fix**: límite generoso o filtrar por año seleccionado en la query.

---

## Fase 3 — Conectividad y experiencia offline

### [x] 3.1 El fallback de ubicación por IP no funciona 🟠 (trivial) — HECHO (2026-07-05, cambiado a ipwho.is)
- **Dónde**: `tracker_screen.dart:181` (`https://ip-api.com/json`).
- **Problema**: ip-api.com solo sirve HTTP en el tier gratuito (HTTPS es de pago), y HTTP plano está bloqueado por la política cleartext de Android → el fallback falla siempre.
- **Fix**: cambiar a un servicio gratuito con HTTPS (p. ej. `ipwho.is` o `ipapi.co/json`).

### [ ] 3.2 Sin detección de conectividad 🟡
- **Fix**: añadir `connectivity_plus`; banner "Sin conexión — tus registros se sincronizarán" (aprovecha la persistencia de Firestore una vez hecho 2.2). Deshabilitar o encolar acciones que requieren red inmediata (fotos del chat).

### [ ] 3.3 Indicador "está escribiendo…" se queda pegado 🟡
- **Dónde**: `database_service.dart:843` (filtro de 8 s solo se evalúa al llegar un snapshot) y `chat_screen.dart:51-57` (`dispose` no limpia el estado typing).
- **Problema**: si alguien mata la app con `typing=true`, su doc queda huérfano y los demás ven "escribiendo…" hasta que otro evento dispare un snapshot.
- **Fix**: limpiar typing en `dispose`; en cliente, reevaluar el filtro con un timer local corto mientras haya usuarios "escribiendo".

### [ ] 3.4 Robustez del callback del widget de escritorio 🟡
- **Dónde**: `main.dart:39` (`interactiveCallback`).
- **Problema**: `await authStateChanges().first` sin timeout (puede colgar el servicio en background); ejecuta el `addEvent` completo, incluido el escaneo de logros de 2.1.
- **Fix**: timeout + ruta ligera de guardado (solo batch + kcoins).

---

## Fase 4 — Limpieza y fallos menores

- [ ] **`setState` tras `await` sin `mounted`** en `_loadFirstPage`, `_loadNextPage`, `_loadAutoGeolocatePreference` y la rama mock de `_getCurrentLocation` (`tracker_screen.dart`) → excepciones "setState after dispose" esporádicas.
- [ ] **Auto-scroll del chat en cada snapshot** (`chat_screen.dart:300`): cualquier reacción o mensaje nuevo arrastra al final aunque estés leyendo historial. Solo hacer scroll si ya estabas abajo o el mensaje es tuyo.
- [ ] **`signUp` con lecturas fuera del `try`** (`auth_service.dart:83`): errores de red muestran mensaje crudo. Registro abierto (whitelist comentada) y "primer usuario = admin" es una carrera en cliente — reactivar whitelist o cerrar registro por reglas.
- [ ] **`scheduleLocalReminder`** (`push_notification_service.dart:87`) usa `Future.delayed` (solo funciona con la app abierta) — migrar a `zonedSchedule` o eliminar.

---

## Cosas que ya están bien (no tocar)

- 60 Hz forzado en Android para ahorrar batería (`main.dart:115`).
- Persistencia offline de Firestore activada (`database_service.dart:108`).
- Paginación del historial de eventos (`getEventsPaged`).
- `IndexedStack` con pestañas lazy: los streams no se re-suscriben al cambiar de pestaña (decisión documentada en `main.dart:204`).
- Precache de audios de Flame y ranking limitado a 100 docs.
