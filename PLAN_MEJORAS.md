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

### [x] 1.3 Las fotos del chat solo las ve quien las envía 🔴 — HECHO (2026-07-05; Storage activado con plan Blaze y reglas desplegadas)
- **Dónde**: `flutter_app/lib/screens/chat_screen.dart:133` (`_sendImage`) y `database_service.dart` (`sendChatMessage`).
- **Problema**: se guarda `image.path` (ruta local del dispositivo) en Firestore y nunca se sube el archivo. Los demás usuarios ven imagen rota. `firebase_storage` ya está en `pubspec.yaml` pero no se usa aquí.
- **Fix**: subir a Firebase Storage en la rama Firebase de `sendChatMessage`, guardar la URL de descarga; mantener ruta local en la rama mock. Añadir reglas de Storage.
- **Esfuerzo**: medio.

### [x] 1.4 Notificaciones push muertas 🔴 — HECHO (2026-07-06; Functions desplegadas a producción)
- **Dónde**: `flutter_app/lib/services/push_notification_service.dart`, `main.dart`.
- **Problema**: `PushNotificationService.init()` no se llama desde ningún sitio: no se pide permiso, el token FCM no se guarda, `onBackgroundMessage` no se registra en `main()`. La notificación local del widget (`interactiveCallback`) falla silenciosamente en Android 13+ sin permiso runtime.
- **Fix aplicado (Parte A — cliente)**: handler de background público en `push_notification_service.dart` registrado en `main()`; `init()` (permiso + primer plano) y `registerDeviceForUser` (token FCM + `onTokenRefresh`) se llaman desde `initState` de `MainNavigationScreen` con sesión activa; `DatabaseService` gana `saveFcmToken`/`getNotificationPrefs`/`updateNotificationPrefs` (ambas ramas). Nuevo menú de notificaciones en Perfil (`notification_settings_screen.dart`): eventos base ON, duelos ON, chat OFF, togglables; las prefs se guardan en `users/{uid}.notifPrefs` para que las Functions las respeten.
- **Fix aplicado (Parte B — servidor)**: `flutter_app/functions/` (JS, `firebase-functions` v2 + `firebase-admin`) con triggers `onEventCreated`, `onDuelCreated`, `onDuelUpdated` (aceptado/finalizado) y `onChatCreated` (opt-in); gating por `notifPrefs` con los mismos defaults que el cliente; limpieza de tokens caducados. Registrado en `firebase.json`. **Desplegado a producción el 2026-07-06** (`firebase deploy --only functions`): 4 funciones v2 en `us-central1`, runtime **Node 22** (Node 20 estaba deprecado), con política de limpieza de Artifact Registry a 3 días. Sin cambios de reglas. **Pendiente solo**: configurar alerta de presupuesto (~5 €) en Google Cloud y probar E2E en Android (permiso + llegada del push).
- **Fix (parte A — cliente, recibir)**: llamar a `init()` tras el login, guardar token en `users/{uid}` con `onTokenRefresh`, registrar handler de background en `main()`, pedir permiso runtime de notificaciones. FCM es gratuito, no depende del plan de facturación.
- **Fix (parte B — servidor, enviar; añadido 2026-07-05)**: los avisos automáticos ("X ha registrado una KK", desafíos de duelo, mensajes del chat) requieren enviar desde un entorno de confianza: la API legacy de envío desde cliente la cerró Google en 2024 y embeber una cuenta de servicio en el APK sería regalar las llaves del proyecto. Crear **Cloud Functions** (el proyecto ya está en plan Blaze desde el 2026-07-05, requisito para desplegarlas):
  - Trigger `onDocumentCreated` en `events` → push al resto de usuarios con token registrado.
  - Trigger en `duels` (creación → aviso al desafiado; cambio a `active`/`finished` → aviso a ambos).
  - Opcional: trigger en `chat` para mensajes normales (valorar si no resulta ruidoso).
  - Infra: carpeta `functions/` + registro en `firebase.json`, desplegar con `firebase deploy --only functions`. Tier gratuito de Blaze: 2M invocaciones/mes (coste real ~0 € para un grupo de amigos). Configurar alerta de presupuesto (~5 €) en Google Cloud al desplegar por primera vez.
- **Esfuerzo**: parte A medio; parte B medio (infra nueva pero funciones sencillas).

---

## Fase 2 — Eficiencia de batería, datos y coste Firestore

### [x] 2.1 Cada registro descarga la colección `events` ENTERA 🔴💰 — HECHO (2026-07-06, contadores agregados sin backfill)
- **Dónde**: `database_service.dart:1599` (`_checkAndUnlockAchievements` → `getAllEvents()` sin límite) y `:1244` (`unlockAchievement` relee el doc de usuario en cada una de sus ~25 posibles llamadas).
- **Problema**: todos los eventos de todos los usuarios, en cada guardado (también desde el widget en background). Mayor consumidor de red/batería/lecturas facturables; crece sin tope.
- **Fix aplicado**: nuevo motor puro `lib/models/achievement_stats.dart` (`AchievementStats.fold` + `evaluateUnlockedAchievements`). La rama Firebase de `addEvent` parte de los contadores ya leídos del doc del usuario (`achStats`), les suma el evento y evalúa los ~45 logros contra ellos; escribe `achStats` + `arrayUnion(achievements)` en el mismo `batch` (cero lecturas extra, una escritura). La rama mock se deja intacta (recalcula en memoria, sin coste). Sin cambios en reglas (el dueño ya puede escribir campos nuevos salvo `role`). Cubierto por `test/achievement_stats_test.dart`.
- **Decisión**: "contar desde ahora" (sin backfill del histórico). Los logros ya desbloqueados no se pierden; el progreso hacia los aún no logrados arranca a cero.
- **Trade-offs asumidos**: `deleteEvent` no decrementa `achStats`; `achStats` se escribe como mapa completo (no `increment`), así que dos guardados simultáneos del mismo usuario podrían perder un fold (riesgo bajo).
- **Esfuerzo**: grande, pero es la mejora con más retorno.

### [x] 2.2 Guardado offline se cuelga con spinner infinito 🟠 — HECHO (2026-07-05)
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

### [x] 2.5 GPS automático en cada arranque 🟡 — HECHO (2026-07-06)
- **Dónde**: `tracker_screen.dart:76-93` (`_loadAutoGeolocatePreference`).
- **Fix aplicado**: al arrancar con autolocalización, nuevo `_getLastKnownLocation()` usa `Geolocator.getLastKnownPosition()` (coste cero, sin encender el GPS) en vez del fix fresco; la posición fresca se pide en `_saveEvent` vía `_refreshFreshLocation()` (best-effort, timeout 5 s, conserva la última conocida si falla). Sin prompt de permiso en el arranque (solo `checkPermission`).

### [x] 2.6 `stats_panel_screen` descarga todos los eventos sin límite 🟡 — HECHO (2026-07-06)
- **Dónde**: `flutter_app/lib/screens/stats_panel_screen.dart:91`.
- **Nota**: los exports CSV/JSON de `profile_screen.dart:363,419` sí necesitan todo legítimamente.
- **Fix aplicado**: `getAllEvents(limit: 2000)` (cap generoso; ordena por fecha desc, conserva lo reciente). Los exports de admin siguen sin límite.

---

## Fase 3 — Conectividad y experiencia offline

### [x] 3.1 El fallback de ubicación por IP no funciona 🟠 (trivial) — HECHO (2026-07-05, cambiado a ipwho.is)
- **Dónde**: `tracker_screen.dart:181` (`https://ip-api.com/json`).
- **Problema**: ip-api.com solo sirve HTTP en el tier gratuito (HTTPS es de pago), y HTTP plano está bloqueado por la política cleartext de Android → el fallback falla siempre.
- **Fix**: cambiar a un servicio gratuito con HTTPS (p. ej. `ipwho.is` o `ipapi.co/json`).

### [x] 3.2 Sin detección de conectividad 🟡 — HECHO (2026-07-06)
- **Fix aplicado**: `connectivity_plus: ^6.1.0` + nuevo `lib/services/connectivity_service.dart` (`onStatusChange` emite estado inicial + cambios; no-op en mock). Banner `_OfflineBanner` en `MainNavigationScreen` ("Sin conexión — tus registros se sincronizarán al volver"). `_sendImage` del chat se bloquea con aviso si no hay red (la foto sube a Storage y necesita conexión; los mensajes de texto los encola la persistencia).

### [x] 3.3 Indicador "está escribiendo…" se queda pegado 🟡 — HECHO (2026-07-06)
- **Dónde**: `database_service.dart:843` (filtro de 8 s solo se evalúa al llegar un snapshot) y `chat_screen.dart:51-57` (`dispose` no limpia el estado typing).
- **Problema**: si alguien mata la app con `typing=true`, su doc queda huérfano y los demás ven "escribiendo…" hasta que otro evento dispare un snapshot.
- **Fix aplicado**: `getTypingUsers()` (rama Firebase) combina los snapshots con un tick periódico (3 s) vía `StreamController`, reevaluando el filtro de frescura aunque no llegue snapshot; `chat_screen.dispose` limpia el typing propio y el stream se cachea en un campo para no re-suscribir en cada rebuild.

### [x] 3.4 Robustez del callback del widget de escritorio 🟡 — HECHO (2026-07-06)
- **Dónde**: `main.dart:39` (`interactiveCallback`).
- **Problema**: `await authStateChanges().first` sin timeout (puede colgar el servicio en background); ejecuta el `addEvent` completo, incluido el escaneo de logros de 2.1.
- **Fix aplicado**: `.timeout(10 s, onTimeout: () => null)` en `authStateChanges().first`. El escaneo pesado de logros ya se eliminó de `addEvent` en 2.1 (contadores agregados en el batch), así que la "ruta ligera" ya está cubierta.

---

## Fase 4 — Limpieza y fallos menores

- [ ] **`setState` tras `await` sin `mounted`** en `_loadFirstPage`, `_loadNextPage`, `_loadAutoGeolocatePreference` y la rama mock de `_getCurrentLocation` (`tracker_screen.dart`) → excepciones "setState after dispose" esporádicas.
- [ ] **Auto-scroll del chat en cada snapshot** (`chat_screen.dart:300`): cualquier reacción o mensaje nuevo arrastra al final aunque estés leyendo historial. Solo hacer scroll si ya estabas abajo o el mensaje es tuyo.
- [ ] **`signUp` con lecturas fuera del `try`** (`auth_service.dart:83`): errores de red muestran mensaje crudo. Registro abierto (whitelist comentada) y "primer usuario = admin" es una carrera en cliente — reactivar whitelist o cerrar registro por reglas.
- [ ] **`scheduleLocalReminder`** (`push_notification_service.dart:87`) usa `Future.delayed` (solo funciona con la app abierta) — migrar a `zonedSchedule` o eliminar.

---

## Fase 5 — Actualización de dependencias y tecnologías

### [ ] 5.1 Actualizar Flutter y dependencias 🟡 (añadido 2026-07-05)
- **Estado al añadirse**: Flutter 3.41.4 estable (marzo 2026, hay versión más nueva disponible); ~90 paquetes con versiones mayores incompatibles con las restricciones actuales de `pubspec.yaml`.
- **Saltos mayores destacados** (requieren revisar breaking changes):
  - Toda la familia Firebase: `cloud_firestore` 5→6, `firebase_auth` 5→6, `firebase_core` 3→4, `firebase_messaging` 15→16, `firebase_storage` 12→13 (se actualizan en bloque).
  - `flutter_lints` 3→6 (traerá lints nuevos que tocar en el código).
  - `flutter_map` 6→8 (API cambiada), `share_plus` 10→13, `file_picker` 8→11, `intl` 0.19→0.20, `csv` 6→8, `archive` 3→4, `package_info_plus` 9→10.
- **Orden sugerido**: `flutter upgrade` → familia Firebase en bloque → `flutter_lints` (y arreglar avisos) → resto por grupos pequeños, con `flutter analyze` + `flutter test` + prueba manual en Windows (mock) y Android tras cada grupo.
- **Nota**: el workflow `.github/workflows/build.yml` sigue siendo el del Flet legacy; aprovechar para eliminarlo o sustituirlo por uno de Flutter.
- **Esfuerzo**: medio-grande. Hacerlo en sesión propia, sin mezclar con cambios funcionales.

---

## Cosas que ya están bien (no tocar)

- 60 Hz forzado en Android para ahorrar batería (`main.dart:115`).
- Persistencia offline de Firestore activada (`database_service.dart:108`).
- Paginación del historial de eventos (`getEventsPaged`).
- `IndexedStack` con pestañas lazy: los streams no se re-suscriben al cambiar de pestaña (decisión documentada en `main.dart:204`).
- Precache de audios de Flame y ranking limitado a 100 docs.
