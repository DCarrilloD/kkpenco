# Plan de mejoras del Widget de Android

> Auditoría realizada el 2026-07-07 sobre `main` (v5.3.0+12).
> Ámbito: el widget de escritorio de Android (`home_widget` 0.9.3). No afecta a Windows/mock ni a los tests.
> Filosofía acordada: en vez de un único widget "perfecto", un **catálogo de diseños** — cada provider es un widget independiente en el selector de Android y cada miembro del grupo coloca el que más le guste (o varios).

---

## Fase 0 — Estado actual (auditoría)

**Lo que hay**: un único widget **"KKpenco Express ⚡"** (4×1): fila de 4 botones (Cabra 🐐, Espurruteo 💧, Normal 💩, Jurásica 🌋). Cada toque registra una KK con valores por defecto (5 min, Casa, dificultad 3) vía isolate de background (`interactiveCallback` en `main.dart:25`) y confirma con una notificación local.

**Ficheros implicados**:
- `flutter_app/lib/main.dart:24-119` — `interactiveCallback` (@pragma vm:entry-point): inicializa Firebase aparte, espera auth con timeout de 10 s, crea el evento y hace `addEvent(waitForServerAck: true)`.
- `android/.../kotlin/com/kkpenco/app/PoopWidgetProvider.kt` — provider; dibuja los 4 iconos con Canvas nativo (bitmaps de 128 px, muy resultones) y engancha los `HomeWidgetBackgroundIntent` (`kkpenco://express?consistency=X`).
- `android/.../res/layout/poop_widget_layout.xml`, `res/xml/poop_widget_info.xml`, `res/drawable/poop_widget_background.xml`.

**Lo que ya está bien (no tocar)**: el patrón isolate + `waitForServerAck` (sin él la escritura moriría en la cola local); el timeout del auth; los iconos Canvas; el fondo redondeado oscuro coherente con la app.

**Carencias detectadas**:
1. **Cero feedback si algo falla**: sin conexión, `addEvent` espera el ack para siempre (el sistema mata el isolate y no hay notificación); con la sesión caducada hace `return` silencioso; si el permiso de notificaciones está denegado, ni siquiera el éxito se comunica. El usuario toca y no sabe si registró.
2. **Doble toque = doble KK**: no hay debounce; dos toques nerviosos crean dos eventos (y el contador del ranking sube dos).
3. **El widget no muestra NADA de información**: la app nunca llama a `HomeWidget.saveWidgetData` (verificado: solo existe `registerInteractivityCallback`). Racha, contador de hoy o última KK son invisibles desde el escritorio.
4. **Sin preview ni descripción** en el selector de widgets (`poop_widget_info.xml` no tiene `previewImage`/`previewLayout`/`description` ni `targetCellWidth/Height` de Android 12+); `resizeMode` solo horizontal.
5. **Tema fijo oscuro**: en fondos de pantalla claros el bloque negro canta; no hay variante day/night.
6. Menor: el evento del isolate lleva `id: 'mock_...'` (patrón legacy pre-fix 1.2; `addEvent` ya lo ignora y genera ID real — limpiar de paso).

---

## Fase 1 — Robustez del registro rápido 🔴 (aplica a TODOS los diseños)

### [x] 1.1 Feedback de resultado real (éxito / offline / sin sesión)
- **Dónde**: `interactiveCallback` (`main.dart`).
- Poner timeout al `addEvent` (~12 s). Tres desenlaces, cada uno con su notificación:
  - Éxito → la actual ("¡Registro añadido! 💩").
  - Timeout/offline → "Sin conexión: se guardará al abrir la app 📡" (la escritura queda en la persistencia local de Firestore y sincroniza al abrir).
  - Sin sesión → "Abre KKpenco e inicia sesión para registrar desde el widget 🔑".
- Además del aviso, escribir el estado en el propio widget (ver 2.1): la notificación puede estar silenciada.
- **Esfuerzo**: pequeño.

### [x] 1.2 Anti-doble-toque
- Guardar `lastQuickAddMillis` vía `HomeWidget.saveWidgetData` al entrar al callback; si el anterior es de hace < 10 s, ignorar el toque (y avisar "¡Tranquilo, ya está registrada! 😅" solo si fue < 2 s… opcional).
- **Esfuerzo**: pequeño. **Test**: unitario de la función pura de decisión (extraerla a un helper testable).

### [x] 1.3 Limpiar el `id: 'mock_...'` legacy del evento del isolate (usar `id: ''`).
- **Esfuerzo**: trivial.

---

## Fase 2 — Datos en el widget (infraestructura) 🟠

### [x] 2.1 Canal de datos app → widget
- La app escribe con `HomeWidget.saveWidgetData` + `HomeWidget.updateWidget` en estos momentos:
  - al **abrir la app** con sesión (junto a `syncEmailWithFirestore` en `MainNavigationScreen.initState`),
  - al **registrar** una KK (tracker y también el isolate del widget al terminar),
  - al **borrar** una KK.
- Claves propuestas (SharedPreferences que los providers leen con `HomeWidgetPlugin.getData`):
  `streak` (racha 🔥), `todayCount`, `monthCount`, `lastPoopMillis`, `lastStatus` (`ok|offline|nosession`), `rankPosition`, `rankTop` (JSON top-3: nombre+contador).
- Un helper único `WidgetDataService` (lib/services) para no repetir las escrituras; branch mock = no-op.
- **Limitación honesta**: los datos se refrescan cuando la app (o el isolate) escribe — no hay polling contra Firestore desde el widget. Es suficiente: la racha/contadores solo cambian cuando TÚ registras; el ranking se refresca al abrir la app. Opcional futuro: un data-message FCM que despierte el refresco (no lo recomiendo aún: batería/complejidad).
- **Esfuerzo**: medio.

### [x] 2.2 Estado "última KK" en el widget Express
- Línea inferior en el layout actual: "Última: 14:32 ✓" / "⏳ pendiente de sincronizar" / "🔑 inicia sesión", leyendo `lastPoopMillis`/`lastStatus`. El provider ya se re-renderiza con `updateWidget`.
- **Esfuerzo**: pequeño (depende de 2.1).

---

## Fase 3 — Catálogo de diseños 🎨 (cada uno coloca el suyo)

> Cada diseño = su `AppWidgetProvider` Kotlin + layout + `appwidget-provider` XML + entrada en el AndroidManifest. Todos conviven en el selector de widgets. El Express actual se mantiene como D1. Los datos vienen de la Fase 2; los registros rápidos reutilizan `interactiveCallback` tal cual (mismo esquema de URI).

### [x] D1 · «Express» — el actual, mejorado (4×1)
```
┌──────────────────────────────────────┐
│         KKpenco Express ⚡           │
│   🐐      💧      💩      🌋        │
│ Cabra Espurruteo Normal Jurásica     │
│        Última: 14:32 ✓               │
└──────────────────────────────────────┘
```
- Solo recibe 1.x + 2.2. Para quien quiere elegir consistencia al vuelo.

### [x] D2 · «La Mojona» — minimal 1×1
```
┌────────┐
│   💩   │   1 toque  → se "arma" (borde ámbar, 5 s)
│  ¡YA!  │   2º toque → registra Normal
└────────┘
```
- Un único botón gigante. El armado en dos toques evita registros por roce (el estado "armado" vive en `saveWidgetData` con caducidad y el provider re-renderiza el borde).
- Tap fuera de la ventana de armado → vuelve a estado normal.
- Para minimalistas. **Esfuerzo**: pequeño-medio (el estado armado es lo único nuevo).

### [x] D3 · «El Vigía» — racha y contadores 2×2
```
┌──────────────────┐
│  🔥 12 días      │
│  Hoy: 2 💩       │
│  Mes: 34         │
│  Última: 14:32   │
│  [ +💩 Normal ]  │
└──────────────────┘
```
- Racha grande arriba (el dato que más pica), contadores debajo, botón de registro Normal al pie. Tocar cualquier zona no-botón abre la app.
- El diseño con mejor relación valor/esfuerzo una vez exista la Fase 2. **Esfuerzo**: pequeño-medio.

### [x] D4 · «El Podio» — mini-ranking 3×2
```
┌───────────────────────────┐
│  🥇 David      34 💩      │
│  🥈 Carlos     29 💩      │
│  🥉 Elena      21 💩      │
│  Tú: 4º (19) — ¡a cagar!  │
└───────────────────────────┘
```
- Snapshot del top-3 + tu posición (claves `rankTop`/`rankPosition` de 2.1, refrescadas al abrir la app). Tocar abre la app en la pestaña Ranking (deep link: `HomeWidget.widgetClicked`/URI inicial → `MainNavigationScreen` con índice 1; hay que añadir ese plumbing, no existe router).
- El más "social": pique visible desde el escritorio. **Esfuerzo**: medio (deep link + render de lista en RemoteViews).

### [x] D5 · «El Trono» — cronómetro Zen 2×1 (opcional, el más ambicioso)
```
┌────────────────────┐
│ 🚽 Sentarse al     │
│    Trono ▶         │
└────────────────────┘
```
- Al tocar: guarda `tronoStartMillis` y abre la app directa al tracker con el cronómetro ya corriendo desde ese instante (el cronómetro usa reloj de pared, así que solo hay que restar el offset al abrir).
- Exige tocar `tracker_screen` (aceptar un inicio externo). Dejar para el final o descartar si no compensa.

**Recomendación de orden**: D3 → D2 → D4 → (D5). D1 se mejora vía Fases 1-2 sin trabajo extra.

---

## Fase 4 — Pulido de plataforma 🟡

### [x] 4.1 Selector de widgets decente
- `previewLayout` (Android 12+) + `previewImage` (fallback) + `android:description` por diseño; `targetCellWidth/Height` para tamaños correctos en Android 12+ y `minWidth/minHeight` como fallback.

### [x] 4.2 Tema claro/oscuro
- `res/drawable-night/` para el fondo y colores de texto vía `res/values(-night)/colors.xml` en todos los layouts (hoy el negro fijo canta en fondos claros). Material You real (colores dinámicos) es posible en 12+ con `@android:color/system_*` — opcional, solo si apetece.

### [x] 4.3 `resizeMode="horizontal|vertical"` y layouts que aguanten el resize sin recortes.

### [ ] 4.4 Pruebas manuales en Android real (no hay forma razonable de test automático de RemoteViews)
- Checklist por diseño: colocar desde el selector (preview correcta), toque con red, toque sin red, doble toque, sesión cerrada, resize, tema claro y oscuro, reinicio del launcher (los bitmaps se regeneran en `onUpdate`).

---

## Cierre (2026-07-07)

Implementado TODO el plan salvo 4.4 (pruebas manuales en Android real, pendientes). Notas de lo hecho:
- `WidgetDataService` (`lib/services/widget_data_service.dart`): una sola query (ranking, incluye el doc propio) publica racha, contadores (de `achStats`), última KK, posición y top-3; **todos los valores como String** (el canal guarda los int de Dart como Integer o Long según tamaño y un `getInt/getLong` equivocado en Kotlin revienta). Se llama al abrir la app, al registrar (tracker e isolate) y al borrar.
- Funciones puras testeadas (`shouldIgnoreQuickTap`, `mojonaTapConfirms`) en `test/widget_quick_tap_test.dart` (47/47 tests).
- `interactiveCallback` enruta por `uri.host` (`express` | `mojona`); timeout de 12 s en `addEvent` con notificación de éxito/offline/sin sesión.
- Deep links `kkpenco://open?tab=N[&trono=1]`: `MainNavigationScreen` escucha `initiallyLaunchedFromHomeWidget` + `widgetClicked`; el Trono usa `TrackerScreen.tronoStartRequest` (ValueNotifier estático) — el instante de inicio es la llegada del intent, no el toque (los PendingIntent de RemoteViews son estáticos; diferencia ~1 s).
- Kotlin: dibujo compartido en `PoopIconDrawer`, lectura de datos en `WidgetData`; providers `Mojona/Vigia/Podio/TronoWidgetProvider` + Express refactorizado (misma clase, con línea de estado).
- Tema day/night vía `values(-night)/colors.xml`; `updatePeriodMillis` diario solo para refrescar el formato de fechas (los re-render reales van por `updateWidget`).
- Verificado: `flutter analyze` limpio, 47/47 tests, `apk --debug` compila (valida Kotlin+XML+manifest). **Pendiente 4.4**: checklist manual en el móvil.

## Orden global sugerido

**1.1 → 1.2 → 2.1 → 2.2 → D3 → D2 → 4.1 → 4.2 → D4 → 4.3 → (D5)**

Las Fases 1-2 son el cimiento (robustez + datos); los diseños son incrementales y cada uno se puede lanzar por separado — no hace falta esperar al catálogo completo para publicar.

## Notas transversales

- **Mock/Windows**: todo el código nuevo de widget va detrás de `TargetPlatform.android` o en el lado Kotlin; `WidgetDataService` con branch mock no-op para que Windows y los 38 tests no se enteren.
- **Batería**: nada de `updatePeriodMillis` agresivo (los providers solo re-renderizan cuando la app escribe datos); los bitmaps se dibujan solo en `onUpdate`.
- **Los providers nuevos NO rompen los widgets ya colocados**: el Express actual conserva su nombre de clase (`PoopWidgetProvider`) — renombrarlo eliminaría los widgets existentes de los escritorios del grupo.
