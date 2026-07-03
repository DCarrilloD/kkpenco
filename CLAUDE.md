# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

KKpenco is a humorous social "poop tracker" Flutter app (Spanish-language UI) backed by Firebase (Auth, Firestore, Storage, Messaging). It is a rewrite of an older Flet/Python app. The actual Flutter project lives in `flutter_app/` — run all commands from that directory.

Note: `.github/workflows/build.yml` still builds the legacy Flet app and references files (`mobile_app/`, `requirements.txt`) that no longer exist. It is stale; do not use it as a reference for how to build.

## Commands

All from `flutter_app/`:

```bash
flutter pub get                        # install dependencies
flutter run -d windows                 # run on Windows (auto-enables mock mode, no Firebase needed)
flutter run                            # run on Android device/emulator (real Firebase)
flutter analyze                        # lint (flutter_lints ruleset)
flutter test                           # run all tests
flutter test test/admin_logic_test.dart   # run a single test file
flutter build apk                      # release Android build
firebase deploy --only firestore:rules # deploy Firestore security rules
```

## Architecture

### Mock mode (the central pattern)

A global flag `useMockData` (declared in `lib/services/auth_service.dart`) switches the entire data layer between real Firebase and in-memory mock data. It is auto-enabled in `main.dart` when running on Windows or when Firebase initialization fails, and tests set it to `true` in `setUp`. **Every method in `AuthService` and `DatabaseService` has a mock branch** — when adding or changing data-layer methods, implement both the Firestore path and the mock path, or Windows development and tests will break. Mock state lives in static in-memory lists with broadcast `StreamController`s in `DatabaseService`.

### Data layer

- `lib/services/database_service.dart` (~2100 lines) is the single data service covering everything: KK events, chat (with reactions and typing presence), rankings, monthly stats, achievements, duels, and the email whitelist. Firestore collections: `events`, `chat`, `users` (with `monthly_stats` subcollection), `typing`, `authorized_emails`.
- `lib/services/auth_service.dart` handles auth and user profiles/roles. The first user ever registered becomes `admin`; roles live on the `users` document and are enforced both client-side (`isAdminUser`) and in `flutter_app/firestore.rules` (e.g., users cannot elevate their own role; event owners can delete events only within 5 minutes).
- Domain model: `KKEvent` in `lib/models/event.dart` with Spanish-named enums (`Consistency`, `PoopColor`, `LocationTag`) that serialize by `displayName`. Event weight is computed via `KKEvent.calculateWeight`.

### State management and navigation

Plain `StatefulWidget`s with services instantiated directly (`DatabaseService()`, `AuthService()` — they are cheap wrappers over singletons). Riverpod is a declared dependency and `lib/providers/auth_provider.dart` defines providers, but there is **no `ProviderScope`** in `main.dart` — Riverpod is effectively dormant; don't assume `ref` is available in widgets.

There is no router. `main.dart` contains `AuthWrapper` (login vs. main) and `MainNavigationScreen`, a 4-tab shell (Tracker, Ranking, COS Chat, Perfil) with a custom `AnimatedSwitcher` 3D scale/fade transition between tabs.

### Juanito Mode minigames (Flame Engine)

`lib/screens/juanito_mode/` holds four minigames (Caca Catch, Flappy Poop, Toilet Jump, Poop Invaders). Each top-level `*_game.dart` is the Flutter wrapper screen; the actual game logic lives in `flame_games/flame_*.dart` as `FlameGame` subclasses using the Flame Component System (separate `PositionComponent` classes per entity with collision callbacks). Flutter↔Flame communication goes through `GameWidget.overlays`. Global mute state is a static on `JuanitoModeScreen`, persisted in `SharedPreferences` (`games_muted`). Achievements grant passive bonuses inside the minigames.

### Android home widget

`interactiveCallback` in `main.dart` is a `@pragma('vm:entry-point')` background-isolate entry point invoked by the Android home widget: it initializes Firebase independently, creates a quick `KKEvent` from URI query parameters, and fires a local notification. Code in this callback cannot rely on any app state.

### Conventions

- UI strings and code comments are in Spanish; keep new user-facing text in Spanish.
- Firebase project: `kkpenco-app-2026` (Android + web configured; Windows intentionally has no Firebase config, which is what triggers mock mode).
