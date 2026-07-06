# Fase 5 — Actualización de Flutter y dependencias

> Exploración realizada el 2026-07-06 con `flutter pub outdated` y revisión del uso real en el código.
> **No se ha actualizado nada todavía**: este documento es el plan para hacerlo en una sesión propia.

## Contexto y objetivo

El proyecto va con **Flutter 3.41.4 (stable, marzo 2026) · Dart 3.11.1** y arrastra **~34 dependencias** por detrás de una versión mayor resoluble, más ~25 con actualizaciones menores bloqueadas por el `pubspec.lock`. El objetivo es ponerse al día de forma **controlada y reversible**, resolviendo los breaking changes por grupos pequeños, sin mezclarlo con cambios funcionales (por eso es su propia fase y su propia sesión/rama).

Ganancias: parches de seguridad y rendimiento, quitar deprecaciones (algunas ya rompen a medias, ver §Riesgos), y dejar el terreno listo para Android 15/16 y las próximas Flutter.

## Metodología (importante)

1. **Rama propia**: `git checkout -b fase5-deps`. Un commit por grupo.
2. **Grupos pequeños y en orden** (§Grupos). Nunca todo de golpe con `flutter pub upgrade --major-versions` a ciegas.
3. **Gate tras cada grupo**: `flutter pub get` → `flutter analyze` (limpio) → `flutter test` (35 verdes) → **prueba manual**: Windows en modo mock (`flutter run -d windows`) **y** Android real (Firebase de verdad, porque muchos de estos paquetes solo importan ahí: Firebase, mapas, share, file_picker, push, widget).
4. **Rollback fácil**: si un grupo se atasca, `git restore pubspec.yaml pubspec.lock && flutter pub get` y se aísla.
5. Regla del proyecto (CLAUDE.md): cualquier cambio en la capa de datos toca **ambas ramas** (Firebase y mock). Aquí es sobre todo API de paquetes, pero ojo con Firebase.

## Estado actual (snapshot 2026-07-06)

- **Flutter 3.41.4** stable (revisión de hace ~4 meses). Primer paso del plan: valorar `flutter upgrade` a la stable del día.
- **Flame** (`flame` 1.37, `flame_audio` 2.12) y **flutter_riverpod** 3.3.2 ya están al día → no se tocan.
- `dart_earcut`, `dart_polylabel2`, `jni`, `record_use`… aparecen como nuevas transitivas que entrarán solas al actualizar los directos (p. ej. flutter_map 8 trae `dart_earcut`).

## Grupos de actualización (en orden recomendado)

### Grupo 0 — Base: Flutter + menores seguros
- `flutter upgrade` (revisar release notes de la stable destino).
- `flutter pub upgrade` (sin `--major-versions`): sube los ~25 bloqueados a su parche (image_picker 1.2.2→1.2.3, geolocator →14.0.3, path_provider, shared_preferences, window_manager, timezone, vm_service, url_launcher_web…). Riesgo bajo.
- **Gate** completo.

### Grupo 1 — Familia Firebase (en bloque) 🔴 el más importante
Se actualizan **juntas** o el resolver se queja:
| Paquete | Actual → Objetivo |
|---|---|
| firebase_core | 3.15.2 → **4.11.0** |
| cloud_firestore | 5.6.12 → **6.6.0** |
| firebase_auth | 5.7.0 → **6.5.4** |
| firebase_messaging | 15.2.10 → **16.4.1** |
| firebase_storage | 12.4.10 → **13.4.3** |

- **Breaking changes a verificar en los CHANGELOG de FlutterFire** (subidas mayores = sobre todo min SDK y limpieza de deprecaciones):
  - Sube el **mínimo de Dart/Flutter, iOS y Android**. Android usa `flutter.minSdkVersion` (heredado), así que con Flutter al día debería bastar; **verificar** que firebase_core 4 no pida un minSdk mayor (histórico: 23). iOS 13+ (poco relevante: iOS no está configurado, `firebase.json` solo tiene android/web/dart).
  - `firebase_auth` 6: **`User.updateEmail` eliminado** (deprecado) → rompe `auth_service.dart:233` (ver §Riesgos). Hay que quitar el fallback.
  - Revisar `firebase_messaging` 16 por cambios en la API de permisos/tokens (el flujo de 1.4: `requestPermission`, `getToken`, `onTokenRefresh`, `onBackgroundMessage`).
  - Las **Cloud Functions** (`flutter_app/functions/`, Node) son independientes: no se tocan aquí.
- **Prueba manual imprescindible en Android**: login/registro, guardar KK, rachas, chat, Storage (fotos), push.

### Grupo 2 — `flutter_lints` 3 → 6 (dev) 🟡
- `flutter_lints: ^6.0.0` (arrastra `lints` 6 y `analyzer` 14).
- Traerá **lints nuevos** → `flutter analyze` sacará avisos que hay que ir arreglando (probablemente `const`, `use_super_parameters`, etc.). Hacerlo en su propio commit para no ensuciar los demás.

### Grupo 3 — `flutter_map` 6 → 8 (+ `latlong2` 0.9→0.10) 🔴 el más invasivo en código
- **Único sitio de uso**: `lib/screens/heatmap_screen.dart` (dos `FlutterMap`).
- Breaking conocido que **ya afecta** al código:
  - **`subdomains` eliminado** en flutter_map 8 (líneas 383 y 485). Hay que pasar de `urlTemplate: '...{s}.basemaps.cartocdn.com/...'` + `subdomains: ['a','b','c','d']` a una URL **sin `{s}`** (host único, p. ej. `https://a.basemaps.cartocdn.com/...`).
  - Verificar firmas de `MapOptions` (ya usa `initialCenter`/`initialZoom`, bien), `TileLayer` (`retinaMode`/`{r}`), `CircleLayer`, `MarkerLayer` en v8.
  - Revisar la línea 307 (`center: LatLng(...)`) según en qué API encaje (cameraFit/constraint).
- Prueba manual: abrir el mapa de calor y el mini-mapa.

### Grupo 4 — `share_plus` 10 → 13 🟠 (API cambiada)
- **3 usos**: `profile_screen.dart:391,448` y `stats_panel_screen.dart:760`, todos `Share.shareXFiles(...)`.
- En v11+ la API pasó a **`SharePlus.instance.share(ShareParams(files: [...], text: ...))`**; `Share.shareXFiles` queda deprecado/eliminado. Migrar las 3 llamadas.
- Prueba manual: exportar CSV, exportar JSON (backup), compartir estadística.

### Grupo 5 — `file_picker` 8 → 11 🟠
- **Uso**: `profile_screen.dart` (importar backup JSON).
- Objetivo **11.0.2** (la resoluble muestra `12.0.0-beta.7`: **evitar beta**, fijar `^11.0.2`).
- v9–11 simplificaron la config de plataforma y ajustaron tipos de retorno (`FilePickerResult`); verificar la llamada de importación.

### Grupo 6 — `connectivity_plus` 6 → 7 🟡
- **Uso**: `lib/services/connectivity_service.dart` (creado en 3.2) y el banner en `main.dart`.
- Verificar que en v7 `onConnectivityChanged`/`checkConnectivity()` sigan devolviendo **`List<ConnectivityResult>`** (el servicio ya trabaja con listas). Si cambió, ajustar `_hasNetwork`.

### Grupo 7 — `home_widget` 0.7 → 0.9 🟠
- **Uso**: `main.dart:134` (`HomeWidget.registerInteractivityCallback`) y el `interactiveCallback` (widget de escritorio/inicio, `@pragma('vm:entry-point')`).
- Los pre-1.0 rompen entre minors: verificar en el CHANGELOG el nombre/firma de `registerInteractivityCallback` y del callback (`Uri?`), y la config nativa Android del widget.
- Prueba manual: registrar una KK desde el widget de inicio en Android.

### Grupo 8 — Utilidades varias (una a una o en mini-lote)
- `csv` 6 → 8 (`ListToCsvConverter().convert` en `profile_screen.dart:382`; verificar API).
- `intl` 0.19 → 0.20 (uso de `DateFormat` en chat/pantallas; suele ser transparente, a veces lo fuerza el propio SDK).
- `google_fonts` 6 → 8 (`lib/theme/app_theme.dart`; API estable, pero repasar que las fuentes sigan cargando).
- `audioplayers` 6.7 → 6.8 (menor; lo usa el Modo Juanito / flame_audio).
- `flutter_launcher_icons` 0.13 → 0.14 (dev; regenerar iconos y comprobar que no cambió el bloque de config en `pubspec.yaml`).
- Transitivas mayores que entrarán solas al subir los directos: `archive` 3→4, `package_info_plus` 9→10, `win32` 5→6, `xml` 6→7, `vector_math` 2.2→2.4, `analyzer` 10→14, etc. No requieren acción salvo que algún directo las exija.

## Riesgos concretos ya detectados en el código

| # | Dónde | Qué pasa al actualizar | Acción |
|---|---|---|---|
| R1 | `auth_service.dart:233` (`user.updateEmail`) | firebase_auth 6 **elimina** `updateEmail` → no compila | Quitar el fallback del `catch`; dejar solo `verifyBeforeUpdateEmail` (ya está en el `try`, línea 229) |
| R2 | `heatmap_screen.dart:383,485` (`subdomains` + `{s}`) | flutter_map 8 elimina `subdomains` → no compila | URL sin `{s}` (host único) |
| R3 | `profile_screen.dart:391,448`, `stats_panel_screen.dart:760` (`Share.shareXFiles`) | share_plus 13 depreca/elimina la API estática | Migrar a `SharePlus.instance.share(ShareParams(...))` |
| R4 | `connectivity_service.dart` | connectivity_plus 7 podría cambiar tipos | Verificar `List<ConnectivityResult>` |
| R5 | `main.dart:134` (`HomeWidget.registerInteractivityCallback`) | home_widget 0.9 puede cambiar firma/config nativa | Revisar CHANGELOG + probar widget en Android |
| R6 | `profile_screen.dart:382` (`ListToCsvConverter`) | csv 8 API | Verificar `convert()` |

## Configuración de plataforma a revisar
- **Android** (`android/app/build.gradle.kts`): `minSdk`/`compileSdk`/`targetSdk` usan los valores de Flutter (`flutter.minSdkVersion`, etc.). Al subir Flutter suben solos; **verificar** que firebase_core 4 y demás no exijan un `minSdk` mayor al heredado. `min_sdk_android: 21` en el bloque `flutter_launcher_icons` del `pubspec.yaml` es solo para los iconos.
- **Gradle / AGP / Kotlin**: si Firebase 4 lo pide, actualizar el wrapper de Gradle y el plugin de Google Services.
- **iOS**: no configurado (`firebase.json` no tiene iOS). Si algún día se añade, iOS 13+ para Firebase 4.
- **Windows**: los plugins con implementación Windows (connectivity_plus, share_plus, path_provider…) ya se regeneran solos; el modo mock evita sus rutas nativas críticas.

## Tabla de dependencias directas (resumen)
| Paquete | Actual | Objetivo | Salto |
|---|---|---|---|
| firebase_core | 3.15.2 | 4.11.0 | mayor |
| cloud_firestore | 5.6.12 | 6.6.0 | mayor |
| firebase_auth | 5.7.0 | 6.5.4 | mayor |
| firebase_messaging | 15.2.10 | 16.4.1 | mayor |
| firebase_storage | 12.4.10 | 13.4.3 | mayor |
| flutter_map | 6.2.1 | 8.3.1 | mayor (invasivo) |
| latlong2 | 0.9.1 | 0.10.1 | menor-pre1.0 |
| share_plus | 10.1.4 | 13.2.0 | mayor (API) |
| file_picker | 8.3.7 | 11.0.2 | mayor (evitar beta 12) |
| csv | 6.0.0 | 8.0.0 | mayor |
| intl | 0.19.0 | 0.20.3 | menor-pre1.0 |
| google_fonts | 6.3.3 | 8.1.0 | mayor |
| home_widget | 0.7.0+1 | 0.9.3 | menor-pre1.0 (rompe) |
| connectivity_plus | 6.1.5 | 7.2.0 | mayor |
| audioplayers | 6.7.1 | 6.8.1 | menor |
| flutter_lints (dev) | 3.0.2 | 6.0.0 | mayor (lints nuevos) |
| flutter_launcher_icons (dev) | 0.13.1 | 0.14.4 | menor |
| geolocator | 14.0.2 | 14.0.3 | parche |
| image_picker | 1.2.2 | 1.2.3 | parche |

## Checklist por grupo
- [ ] `pubspec.yaml` editado (rango del grupo)
- [ ] `flutter pub get` sin conflictos
- [ ] `flutter analyze` limpio (arreglar breaking + lints)
- [ ] `flutter test` (35 verdes)
- [ ] Prueba manual Windows (mock)
- [ ] Prueba manual Android (Firebase real) del área afectada
- [ ] Commit del grupo

## Al terminar toda la Fase 5
- Marcar **5.1** en `PLAN_MEJORAS.md`.
- Considerar el workflow legacy: `.github/workflows/build.yml` sigue siendo el del Flet muerto (referencia `mobile_app/`, `requirements.txt`). Aprovechar para **eliminarlo o sustituirlo** por uno de Flutter (build APK + analyze + test).
- `firebase deploy` de reglas/Storage no se ve afectado; las Cloud Functions tampoco.
