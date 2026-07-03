# Flame Engine - Modo Juanito

Este directorio contiene los cuatro minijuegos implementados con **Flame Engine** y el **Flame Component System (FCS)**. La migración desde las implementaciones legacy (CustomPainter + Timer) está **completada**: los antiguos `*_game.dart` de `juanito_mode/` son ahora wrappers finos que alojan estos juegos vía `FlameGameHost`.

## Juegos:
- `flame_caca_catch.dart` — Caca Catch (atrapa ítems con el inodoro)
- `flame_flappy_poop.dart` — Flappy Poop (estilo Flappy Bird)
- `flame_toilet_jump.dart` — Toilet Jump (plataformas verticales estilo Doodle Jump)
- `flame_poop_invaders.dart` — Poop Invaders (matamarcianos con jefes y object pooling)

## Arquitectura (SOLID):
- **SRP:** las lógicas físicas (colisiones, gravedad) viven en componentes separados de los visuales (`PositionComponent` + `render`).
- **OCP:** cada enemigo/powerup es un componente FCS con su propio `update(dt)`.
- **DIP:** la comunicación Flutter ↔ Flame se hace mediante callbacks tipados del constructor del juego; el chrome común (HUD, pausa, mute, overlay) está en `../flame_game_host.dart`.
- `sprite_rasterizer.dart` cachea dibujados vectoriales pesados como `ui.Image` para no pagar ese coste a 60 FPS.
