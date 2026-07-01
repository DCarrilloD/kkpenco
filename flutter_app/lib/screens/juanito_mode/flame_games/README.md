# Flame Engine Migration - Modo Juanito

Este directorio contendrá las versiones migradas de los minijuegos originales usando **Flame Engine** y el **Flame Component System (FCS)**.

## Archivos Pendientes por Migrar:
- `flame_caca_catch.dart`
- `flame_flappy_poop.dart`
- `flame_toilet_jump.dart`
- `flame_poop_invaders.dart`

## Notas Arquitectónicas (SOLID):
- **SRP:** Separar lógicas físicas (colisiones, gravedad) de los componentes visuales (`SpriteComponent`).
- **OCP:** Utilizar el sistema FCS donde cada clase enemiga o powerup sea un componente separado que implemente su propio `update(dt)`.
- **DIP:** Enlazar la comunicación entre Flutter (JuanitoModeScreen) y Flame a través de `GameWidget.overlays`.
