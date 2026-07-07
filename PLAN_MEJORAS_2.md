# Plan de mejoras KKpenco v2

> Auditoría realizada el 2026-07-07 sobre el estado actual de `main` (v5.2.3+11, Fases 1–5 del plan anterior completadas y mergeadas).
> Estado de partida: `flutter analyze` limpio, 35/35 tests pasan. Los fallos de abajo son de lógica/reglas, no de compilación.
> Orden sugerido: **1.1 → 1.2 → 2.1 → 2.2 → 1.3 → 2.4 → 2.3 → 3.x**.

**Recordatorios transversales** (de CLAUDE.md):
- Cada cambio en la capa de datos necesita **ambas ramas: Firestore y mock** (`useMockData`).
- Los cambios de reglas se despliegan aparte: `firebase deploy --only firestore:rules`.

---

## Fase 1 — Bugs críticos: funcionalidad rota en producción

### [x] 1.1 "Autodestrucción de Cuenta" falla SIEMPRE en producción 🔴
- **Dónde**: `flutter_app/lib/services/database_service.dart:2002` (`deleteAllUserData`), flujo en `profile_screen.dart:1428`.
- **Problema**: el batch único de borrado es imposible de ejecutar con las reglas actuales:
  1. Borra docs de `streaks`, `zen_profiles` y `achievements` (`database_service.dart:2054-2056`), colecciones **sin reglas** → denegado por defecto → **el batch entero falla para todos, incluido el admin** (las reglas se evalúan aunque el doc no exista).
  2. Borrar `users/{uid}` solo lo permiten las reglas a admins (`firestore.rules:30`), no al propio dueño.
  3. Borrar eventos propios de más de 5 minutos está denegado para no-admins (`firestore.rules:55-56`).
  4. Un batch de Firestore admite máx. 500 operaciones; con historial largo revienta igualmente.
- **Efecto**: el diálogo muestra error y la cuenta nunca se borra (los datos tampoco). Si algún día el batch pasara parcialmente, quedarían datos huérfanos con la cuenta de Auth ya eliminada.
- **Fix recomendado**: mover el borrado a una **Cloud Function `onCall`** (`deleteMyAccount`): con Admin SDK ignora reglas, borra `events` del uid + `monthly_stats` + `users/{uid}` + avatar/fotos de Storage en lotes, y al final borra el usuario de Auth. El cliente solo reautentica y llama a la función. Quitar del cliente los deletes de `streaks`/`zen_profiles`/`achievements` (colecciones que no existen).
- **Fix mínimo alternativo** (sin Functions): reglas que permitan al dueño borrar su doc de usuario y sus eventos sin límite de tiempo cuando se auto-elimina no son expresables de forma limpia → no recomendado; ir a la Function.
- **Esfuerzo**: medio. **Test**: E2E manual en Android.

### [x] 1.2 No se puede borrar una KK recién registrada (ID fantasma) 🔴
- **Dónde**: `tracker_screen.dart:420` (`id: 'mock_${...}'`), `:456` (se inserta ese objeto en `_eventsList`), `database_service.dart:315` (el ID real lo autogenera `_eventsRef.doc()`), `deleteEvent` en `database_service.dart:492`.
- **Problema**: el evento que se muestra en el historial tras guardar lleva un ID local falso (`mock_...`) que nunca coincide con el doc real de Firestore. El botón de eliminar solo aparece en los primeros 5 minutos (`tracker_screen.dart:1313-1314`)… que es exactamente la ventana en la que el ID es falso:
  - **Firebase**: `deleteEvent` apunta a un doc inexistente → las reglas evalúan `resource.data` sobre null → permission-denied → error en pantalla. El evento real sigue existiendo.
  - **Mock**: `addEvent` mock genera OTRO id distinto (`database_service.dart:254`), así que el `removeWhere` no borra nada pero el contador del ranking sí se decrementa → contadores desincronizados.
- **Fix**: que `addEvent` genere el ID antes del batch y lo **devuelva** (o devuelva el `KKEvent` persistido), y que `_saveEvent` inserte en `_eventsList` el evento con el ID real. En la rama mock, respetar el mismo ID devuelto.
- **Esfuerzo**: pequeño. **Test**: unitario mock (guardar → borrar → evento fuera y contador correcto).

### [x] 1.3 Backup/restore puede corromper datos (y normalmente falla) 🔴
- **Dónde**: `profile_screen.dart:387,445` (`getAllEvents()` sin filtro), `_importFromJSON` (`profile_screen.dart:498`), `importBackupEvents` (`database_service.dart:2061`).
- **Problemas encadenados**:
  1. El "backup personal" (visible para TODOS los usuarios) exporta **los eventos de todo el grupo**, no solo los propios.
  2. Al restaurar, `importBackupEvents` reescribe `userId` con el uid propio para **todos** los eventos del JSON → restaurar un backup grupal te adjudica las cacas de todos (y pone tu `poopCount` al total del grupo).
  3. Para un usuario normal ni siquiera llega ahí: el borrado previo de sus eventos antiguos (`database_service.dart:2139-2144`) viola la regla de 5 minutos → permission-denied. Para un **admin** sí pasa → corrupción real (sobreescribiría eventos ajenos, cuyos IDs vienen en el backup, cambiándoles el `userId`… la regla lo deniega para no-admin, pero el admin puede).
  4. Los batches de borrado (eventos y monthly_stats) no están troceados a 500 ops.
- **Fix**:
  - Exportar como backup personal **solo los eventos del uid propio** (`where userId ==`); dejar `getAllEvents()` únicamente para el CSV de admin.
  - En el import, descartar (o abortar con aviso) los eventos cuyo `userId` original no sea el propio, en vez de reasignarlos.
  - Generar IDs nuevos al importar (no reutilizar los del JSON) para no chocar con docs ajenos.
  - Trocear todos los batches a 500 y recalcular `achStats` desde los eventos importados (hoy queda desincronizado).
- **Esfuerzo**: medio.

---

## Fase 2 — Funcionalidad degradada en producción (mock sí, Firebase no)

### [x] 2.1 Ranking sin rachas, títulos ni botón de empujón 🟠
- **Dónde**: `database_service.dart:598-613` (`getRanking`, rama Firebase) vs `ranking_screen.dart:255-256, 390-391`.
- **Problema**: la rama Firebase solo mapea `uid/username/poopCount/lastPoop`, pero la UI lee `currentStreak` y `equippedTitle`. Con Firebase real las rachas 🔥, los títulos 👑 y el botón Nudge (requiere `streak > 0`) **no aparecen nunca**. En mock sí (por eso no se notó en Windows).
- **Fix**: añadir `currentStreak`, `maxStreak`, `equippedTitle` (y de paso `photoURL` si se quiere avatar) al map de `getRanking`. Una línea por campo; los datos ya están en el doc de usuario.
- **Esfuerzo**: trivial.

### [x] 2.2 Duelos: condición de fin distinta en mock y Firebase; los terminados se muestran "EN CURSO" para siempre 🟠
- **Dónde**: `database_service.dart:1585-1693` (`_updateActiveDuelsCount`), `ranking_screen.dart:64` (banner).
- **Problemas**:
  1. **Mock**: el duelo termina al llegar alguien a 5 puntos. **Firebase**: solo termina cuando pasa `endDate` (7 días) y además alguien registra un evento después. Comportamientos incompatibles: en producción un 5-0 sigue "en curso" días.
  2. El banner trata todo lo que no es `pending` como "DUELO EN CURSO ⚔️": los duelos `finished` se muestran activos **para siempre** (con "Restante: 1d" por el `max(1, …)` de `_getDaysRemaining`, `ranking_screen.dart:513-519`). Nunca se limpian.
  3. `getActiveDuels` no filtra por estado → la lista crece sin tope con cada duelo histórico.
- **Fix**: decidir la regla de fin (sugerido: primero a 5 **o** fin de plazo, lo que llegue antes) e implementarla igual en ambas ramas; filtrar `finished` en la query (o mostrar tarjeta de resultado 48 h y luego ocultar); opcional: borrar/archivar duelos viejos.
- **Esfuerzo**: pequeño-medio.

### [ ] 2.3 Registro abierto a cualquiera; la whitelist es decorativa 🟠 (privacidad)
- **Dónde**: `auth_service.dart:82-87` (chequeo de whitelist desactivado), `admin_panel_screen.dart` (panel que gestiona una lista sin efecto), reglas con `allow read: if request.auth != null` en todo.
- **Problema**: cualquiera con el APK (la config de Firebase va dentro) puede crear una cuenta y **leer todos los eventos, chat, fotos y perfiles del grupo**. El panel de administración da sensación de control que no existe.
- **Fix recomendado**: **blocking function** de Firebase Auth (`beforeUserCreated`) que rechace registros cuyo email no esté en `authorized_emails` (ya hay plan Blaze y carpeta `functions/`). Alternativa sin Functions: regla de `users` create que exija `exists(/authorized_emails/$(email))` + reglas de datos que denieguen lectura a usuarios sin doc en `users`. Marcar `registered: true` al usarse. Si se decide dejarlo abierto conscientemente, retirar el panel de whitelist para no confundir.
- **Esfuerzo**: medio.

### [x] 2.4 El dispositivo sigue recibiendo pushes de la cuenta cerrada 🟡 (privacidad)
- **Dónde**: `push_notification_service.dart:76-89` (`registerDeviceForUser`), `auth_service.dart:199` (`signOut` no limpia nada).
- **Problemas**:
  1. Al cerrar sesión no se borra `fcmToken` del doc del usuario → el móvil sigue recibiendo los avisos (incluido contenido del chat) de la cuenta antigua.
  2. Cada login añade otro listener de `onTokenRefresh` sin cancelar el anterior → tras cambiar de cuenta, una renovación de token escribe el token en **ambos** docs de usuario.
- **Fix**: en `signOut`/`deleteAccount`, borrar `fcmToken` (FieldValue.delete()) y `FirebaseMessaging.deleteToken()`; guardar la suscripción de `onTokenRefresh` en un campo y cancelarla antes de re-suscribir.
- **Esfuerzo**: pequeño.

---

## Fase 3 — Robustez, eficiencia y limpieza

### [x] 3.1 Streams creados dentro de `build` (re-suscripción en cada rebuild) 🟡
- **Dónde**: `chat_screen.dart:322` (`getChatMessages()`), `ranking_screen.dart:49` (`getActiveDuels`) y `:180` (`getRanking`), `admin_panel_screen.dart:146` (`getAuthorizedEmails`).
- **Problema**: cada rebuild (abrir/cerrar teclado en el chat, cualquier `setState`) crea un stream nuevo → el `StreamBuilder` pasa por `waiting` (parpadeo de spinner) y se re-listen a Firestore. El typing stream ya se cachea en un campo (fix 3.3 del plan anterior); aplicar el mismo patrón al resto.
- **Fix**: inicializar los streams en `initState` y referenciarlos desde `build`.
- **Esfuerzo**: trivial por pantalla.

### [x] 3.2 `changeEmail` desincroniza Firestore 🟡
- **Dónde**: `auth_service.dart:229-235`.
- **Problema**: `verifyBeforeUpdateEmail` solo cambia el email cuando el usuario pulsa el enlace del correo, pero el doc de Firestore se actualiza inmediatamente → si nunca confirma, Auth y Firestore quedan con emails distintos.
- **Fix**: no tocar Firestore ahí; sincronizar el email al detectar el cambio en Auth (p. ej. tras `user.reload()` en el arranque) o simplemente dejar de duplicar el email en Firestore.
- **Esfuerzo**: pequeño.

### [x] 3.3 Economía de Kcoins: lecturas extra y carreras 🟡
- **Dónde**: `addKcoins` (`database_service.dart:1236-1245`: un `get` tras cada increment solo para el logro `caca_capitalist`), `buySkin` (`:1251-1289`: lee el perfil FUERA de la transacción y descuenta sin re-validar → dos compras simultáneas pueden dejar saldo negativo; `buyPowerupTransaction` sí lo hace bien).
- **Fix**: en `buySkin`, validar saldo dentro de la transacción (copiar el patrón de `buyPowerupTransaction`); en `addKcoins`, evaluar el logro solo cuando el increment sea positivo y aprovechar lecturas ya hechas (o usar el `achStats` del batch de `addEvent`).
- **Esfuerzo**: pequeño.

### [x] 3.4 Gating de admin por nombre visible 🟡
- **Dónde**: `profile_screen.dart:701`: `_isAdmin || email == 'd.carrillo.d@gmail.com' || displayName == 'admin'`.
- **Problema**: cualquiera que se renombre a "admin" ve el panel de administración y el export CSV global (las escrituras las frenan las reglas, pero la lectura global de eventos está permitida a todo autenticado). Además hay un email hardcodeado.
- **Fix**: dejar solo `_isAdmin` (rol de Firestore). El email hardcodeado sobra: el rol ya se asigna por consola.
- **Esfuerzo**: trivial.

### [x] 3.5 Divergencias menores del modo mock 🟢
- `getEvents(userId)` mock no filtra por usuario (`database_service.dart:524-528`) → en Windows el historial muestra eventos de todos.
- `getChatMessages` mock ignora `limit`.
- **Esfuerzo**: trivial; solo afecta a desarrollo.

### [x] 3.6 Contraseña fija del panel de estadísticas 🟢
- **Dónde**: `profile_screen.dart:1580` (`'kkpenco2026'` en el APK).
- **Nota**: es un candado cosmético (el dato ya es legible por cualquier usuario autenticado). Decidir si se quita el diálogo o se acepta como está; no invertir en "asegurarlo".

---

## Fase 4 — Optimización de los minijuegos (CPU/GPU/batería)

> Auditoría de eficiencia de `lib/screens/juanito_mode/` (2026-07-07). Los cuatro juegos comparten los mismos patrones; el orden de los puntos es el de mayor a menor impacto. El fix de la fuga de Poop Invaders (`c38ea61`) ya demostró que esta zona es sensible: estos puntos son la misma familia de problema.

### [x] 4.1 `TextPainter` creado y layouteado EN CADA FRAME por cada emoji 🔴 (el mayor coste)
- **Dónde** (todas las variantes del mismo patrón):
  - `flame_poop_invaders.dart:1106-1113` (`GameParticleComponent.render`): cada partícula construye `TextPainter` + `layout()` + `paint()` por frame. Y se generan sin parar: la nave emite 🧼 a ~13/s (`PlayerShip.update:406`), cada láser del jugador emite ✨ al 22 % por frame (`LaserComponent.update:582`), y cada explosión suelta 8–20. Con 30–60 partículas vivas son **miles de layouts de texto por segundo** — el shaping de emoji es de lo más caro que se puede hacer en un render loop.
  - `flame_caca_catch.dart:461-466` (`FallingItem.render`): cada ítem emoji (💩/🧻/✨/skin) re-layoutea su `TextPainter` por frame; en frenesí hay un spawn cada 0,15 s y decenas de ítems vivos.
  - Los cuatro `FloatingTextComponent` duplicados (caca_catch:560, invaders:1063, flappy:439, toilet_jump:658): texto inmutable, re-layouteado 60 veces/s solo para cambiar el alpha.
  - `PowerupItem.render` (invaders:1029) y la estrella de `PipePair.render` (flappy:415).
- **Fix**: caché estática `Map<String, ui.Image>` (clave: emoji+tamaño) rasterizada una vez con `SpriteRasterizer`, y `drawImage` con `Paint()..color = white.withOpacity(alpha)` para el desvanecido. Bonus: el fade actual vía `TextStyle(color:)` **no funciona con emoji** (los glifos de color ignoran el fill), así que hoy se paga el coste sin obtener el efecto; con `drawImage` + alpha sí se ve.
- **Extra**: unificar los 4 `FloatingTextComponent` en `shared_game_components.dart` (son casi idénticos).
- **Esfuerzo**: pequeño-medio. Es la mejora con más FPS/batería por línea de código.

### [x] 4.2 SFX con `FlameAudio.play` crean un `AudioPlayer` nuevo por disparo 🟠
- **Dónde**: `shared_game_components.dart:11` (`GameAudio.play`), usado para `shoot.wav` en cada disparo (cadencia 0,36 s, **0,15 s con burst**), `coin.wav` por cada objeto atrapado, `jump.wav` por cada rebote de plataforma.
- **Problema**: `FlameAudio.play` instancia y desecha un `AudioPlayer` nativo por llamada; a 3–7 SFX/s produce churn de GC y microparones en Android.
- **Fix**: `FlameAudio.createPool('shoot.wav', maxPlayers: 2-4)` (AudioPool) para los 5 SFX, creados una vez al precargar (`juanito_mode_screen._precacheFlameAudios`), y `GameAudio` que use el pool.
- **Esfuerzo**: pequeño.

### [x] 4.3 Rasterización por INSTANCIA en vez de por TIPO (láseres y enemigos) 🟠
- **Dónde**: `flame_poop_invaders.dart:538-541` (`LaserComponent.onLoad`) y `:677-686` (`InvaderEnemy.onLoad`).
- **Problema**: cada láser disparado ejecuta `PictureRecorder → toImage` (subida a GPU asíncrona) en su `onLoad`… y solo existen ~6 combinaciones visuales de láser. Con burst son ~7 rasterizaciones/s + las de cada enemigo de cada oleada, para regenerar siempre las mismas texturas. Los `_disableAndPool()` (`:553`, `:1092`) delatan que se planeó pooling y nunca se implementó.
- **Fix**: caché estática por clave de tipo (`type+fromPlayer` para láseres; `visualType+type+bossType+isDamaged` para enemigos), compartida entre instancias y entre partidas; las instancias solo hacen `drawImage`. Con la caché compartida, los `dispose()` por instancia se sustituyen por una limpieza única al salir del Modo Juanito. Opcional: pool real de `LaserComponent`/`GameParticleComponent` para eliminar también el churn de hitboxes.
- **Esfuerzo**: medio.

### [x] 4.4 Fondos y tuberías redibujados íntegros cada frame 🟡
- **Dónde**: `BackgroundComponent` (caca_catch:243), `DeepSpaceBackground` (invaders:329, la rejilla), `ParallaxBackground` (flappy:141), `ParallaxSky` (toilet_jump:239); `PipePair.render` (flappy:385-394).
- **Problema**: gradiente a pantalla completa + rejilla de ~40 `drawLine` regenerando sus `ui.Gradient` cada frame. En `PipePair`, dos `ui.Gradient` nuevos por tubería y por frame cuando son constantes (el ancho es fijo de 50 px y no dependen de `gapY`).
- **Fix**: los shaders de tubería → `static final`; gradiente+rejilla del fondo → rasterizar a `ui.Image`/`Picture` una vez por nivel (las estrellas animadas siguen dibujándose encima en vivo).
- **Esfuerzo**: pequeño.

### [x] 4.5 Háptico en CADA disparo automático 🟡
- **Dónde**: `flame_poop_invaders.dart:412` (`_fireLaser` → `HapticFeedback.selectionClick()`).
- **Problema**: el disparo es automático y continuo (hasta ~7/s con burst): cada tick es un salto por platform channel y vibración física constante → batería. Los hápticos de eventos discretos (daño, powerup, rebote) están bien; el del autodisparo no aporta.
- **Fix**: quitarlo (o limitarlo a 1 de cada N). Trivial.

### [x] 4.6 Texturas cacheadas sin `dispose` en algunos componentes 🟡
- **Dónde**: `ToiletPlayer.cachedToiletImage` (caca_catch:268), `PoopPlayer.cachedPoopImage` (flappy:202), `JumpingPoop.cachedPoopImage` (toilet_jump:297) y `ToiletJumpFlameGame.cachedBacteriaImage` (toilet_jump:46) no se liberan en `onRemove`, mientras que `PlayerShip`, `LaserComponent` e `InvaderEnemy` sí lo hacen (fix `c38ea61`).
- **Problema**: cada "Jugar de nuevo" crea un juego nuevo y filtra las texturas del anterior. Son pequeñas (30–100 px), pero es la misma fuga que ya causó la ralentización de Invaders, en versión lenta.
- **Fix**: replicar el patrón `onRemove { image?.dispose(); }` en los 4 sitios (con la caché compartida de 4.3, esto converge en una sola limpieza).
- **Esfuerzo**: trivial.

### [x] 4.7 La música del menú Zen se STREAMEA de una URL externa 🟠 (datos/batería/robustez)
- **Dónde**: `juanito_mode_screen.dart:280` (`https://www.soundhelix.com/examples/mp3/SoundHelix-Song-16.mp3`, en `ReleaseMode.loop`).
- **Problema**: cada visita al menú del Modo Juanito descarga un MP3 de un servidor de terceros en bucle (datos móviles + radio encendida = batería), y sin conexión o si soundhelix cambia, silencio. Los minijuegos ya usan assets locales.
- **Fix**: empaquetar la pista del menú como asset local (como `Village_of_Seven_Springs.mp3`) o reutilizar una de las existentes.
- **Esfuerzo**: trivial (+ ~2-4 MB de APK, o cero si se reutiliza pista).

### [x] 4.8 Animaciones basadas en `DateTime.now()` en render 🟢
- **Dónde**: llamas del jefe y de la nave (invaders:837,472), estrellas parpadeantes (flappy:169, toilet_jump:275), escáner robot (`shared_game_components.dart:407`), etc.
- **Problema**: menor. Además de leer el reloj del sistema decenas de veces por frame, las animaciones siguen "avanzando" con el juego en pausa. Lo limpio es acumular `dt` en `update` (como ya hace la bacteria de caca_catch con `age`).
- **Esfuerzo**: pequeño; hacerlo de paso al tocar cada render.

### [x] 4.9 Mojibake visible en la tienda 🟢 (cosmético, no eficiencia)
- **Dónde**: `juanito_mode_screen.dart:1144` (`'ASPECTOS DE CACA ­ƒÄ¡'`) y `:1285-1288` (los 4 `DropdownMenuItem` del filtro: `'­ƒÜ¢'`, `'­ƒÆ®­ƒòè´©Å'`…), más comentarios en `:194,516,536,1140,1251,1439`.
- **Problema**: emojis corrompidos (UTF-8 releído como CP437 en algún editor) que el usuario VE en la tienda y el filtro de potenciadores.
- **Fix**: restaurar los emojis (🎭, 🚽, 💩🕊️, 👾). Trivial.

**Lo que ya está bien en los juegos (no tocar)**: el patrón `SpriteRasterizer` en sí (jugador, nave, enemigos cachean su dibujo vectorial pesado); `drawPoop` solo se ejecuta en rasterizaciones, nunca por frame; los wrappers ya cuantizan los callbacks de alta frecuencia (`onTimeChanged` por segundo, `onFeverChanged` en pasos de 5 %); el reloj Zen vive en un `ValueNotifier` y la música se pausa en background; los SFX se precargan al entrar al modo.

**Cierre de Fase 4 (2026-07-07)**: implementada completa. Notas de lo hecho:
- `EmojiSprites` (caché estática emoji+tamaño, rasterizada a 3x con `toImageSync`) y `SpriteCache` (texturas por clave de tipo, compartidas entre instancias y partidas) viven en `sprite_rasterizer.dart`; limpieza única en `JuanitoModeScreen.dispose()`.
- `FloatingTextComponent` unificado en `shared_game_components.dart` (rasteriza el texto una vez; fade con alpha del Paint; `wobble:` reproduce la rotación/pop de Invaders).
- `GameAudio` usa `AudioPool` por SFX (creados en `_precacheFlameAudios` una vez por sesión de app; fallback a `FlameAudio.play` si el pool falla).
- Fondos: Invaders y Caca Catch/Flappy graban gradiente+rejilla en un `ui.Picture` (regenerado solo al cambiar nivel/fiebre); `ParallaxSky` recrea su shader solo cada 40 px de ascenso; shaders de `PipePair` ahora `static final`.
- El pooling real de `LaserComponent`/`GameParticleComponent` (opcional de 4.3) no se implementó; los `_disableAndPool()` siguen siendo `removeFromParent()`.
- 4.8 aplicado en los render por frame (llamas de la nave, auras de jefes, estrellas de Flappy/Toilet Jump, zigzag del rayo eléctrico); los usos de `DateTime.now()` que solo corren al rasterizar (accesorios de `drawPoop`) y los fallbacks se dejaron como estaban.
- Verificado: `flutter analyze` limpio y 35/35 tests. Pendiente de validar FPS/batería en Android real.

---

**Cierre de Fases 1–3 (2026-07-07)**: implementado todo salvo 2.3 (whitelist), que se decidió posponer. Notas:
- **1.1**: nueva Cloud Function `deleteMyAccount` (onCall, en `functions/index.js`) que borra eventos+monthly_stats+doc de usuario en lotes de 500, Storage (avatar y `chat_images/{uid}`) y al final el usuario de Auth. Cliente: `AuthService.deleteMyAccountRemote` (reautentica → llama → signOut local); se añadió la dependencia `cloud_functions`. `deleteAllUserData` queda solo para mock. **Desplegada el 2026-07-07** (`deleteMyAccount` callable v2, us-central1, junto con la actualización de las 4 funciones de push).
- **1.2**: `addEvent` genera el ID antes del batch y devuelve el evento persistido; el tracker inserta ese. Test de regresión en `test/event_lifecycle_test.dart`.
- **1.3**: backup personal exporta solo eventos propios (`getUserEvents`); el import descarta eventos ajenos (con aviso), genera SIEMPRE IDs nuevos, trocea los borrados a 500 y recalcula `achStats`/racha/poopCount desde lo importado.
- **2.1**: `getRanking` mapea `currentStreak`/`maxStreak`/`equippedTitle`/`photoURL`.
- **2.2**: regla única "primero a 5 (`duelTargetScore`) o fin de plazo" en ambas ramas; al finalizar se escribe `finishedAt` y el banner muestra la tarjeta de resultado 48 h (`_finishedDuelVisibleHours`) y luego la oculta; los `finished` históricos sin `finishedAt` se ocultan. Test en `event_lifecycle_test.dart`.
- **2.4**: `unregisterDeviceForUser` (cancela `onTokenRefresh`, borra `fcmToken` con `FieldValue.delete()` y hace `deleteToken()`) llamado al cerrar sesión y al borrar cuenta; `registerDeviceForUser` cancela la suscripción anterior antes de re-suscribir.
- **3.1**: streams de chat/ranking/duelos/whitelist cacheados como campos `late final`.
- **3.2**: `changeEmail` ya no escribe en Firestore; `syncEmailWithFirestore()` reconcilia al arrancar (llamado desde `MainNavigationScreen.initState`).
- **3.3**: `buySkin` valida saldo y skins dentro de la transacción; `addKcoins` solo relee el saldo con incrementos positivos y deja de leer cuando `caca_capitalist` ya está desbloqueado (caché de sesión).
- **3.4**: el gating de admin del perfil usa solo `_isAdmin` (rol de Firestore); fuera el email hardcodeado y el `displayName == 'admin'`.
- **3.5**: `getEvents` y `getEventsPaged` mock filtran por usuario; `getChatMessages` mock respeta `limit`.
- **3.6**: se quitó el diálogo de contraseña fija (`kkpenco2026`) del panel de stats; con biometría activada se sigue pidiendo, sin ella se entra directo.
- Verificado: `flutter analyze` limpio, 38/38 tests (3 nuevos). **Pendiente E2E en Android real** (sobre todo 1.1 tras desplegar la función, y 2.4 con dos cuentas).

## Pendientes heredados del plan anterior

- [ ] Prueba manual en Android real del paquete de dependencias de Fase 5 (login, guardar KK, chat+fotos, push, mapa, export/import, widget). La rama `fase5-deps` **ya está mergeada en `main`**; la rama puede borrarse.
- [ ] Alerta de presupuesto (~5 €) en Google Cloud para las Functions (pendiente desde 1.4).

## Cosas que están bien (no tocar)

- Reglas de Firestore y Storage razonables en general (roles, firma de mensajes de sistema, validación de duelos, límites de tamaño/tipo en Storage).
- Cloud Functions de push: correctas, con limpieza de tokens caducados y defaults idénticos al cliente.
- `addEvent`: escritura optimista + logros por contadores agregados en un solo batch (Fase 2.1 anterior) funciona bien.
- Cronómetro con reloj de pared, ciclo de vida del audio de Juanito, banner offline, typing con tick de frescura: los fixes del plan v1 siguen sanos.
- `analyze` limpio y suite de tests verde.
