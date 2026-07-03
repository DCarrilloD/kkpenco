import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';
import 'in_game_overlay.dart';
import '../juanito_mode_screen.dart';

/// Chrome compartido para alojar un minijuego Flame:
/// cabecera (puntuación, título, mute/pausa/salir), contenedor con borde,
/// HUD superpuesto y overlay de pausa/fin de partida.
class FlameGameHost extends StatefulWidget {
  final Game game;
  final String title;
  final Color accentColor;
  final Color backgroundColor;
  final int score;
  final int record;
  final bool isPaused;
  final bool isGameOver;
  final List<Widget> hudChildren;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onQuit;

  const FlameGameHost({
    super.key,
    required this.game,
    required this.title,
    required this.accentColor,
    required this.backgroundColor,
    required this.score,
    required this.record,
    required this.isPaused,
    required this.isGameOver,
    this.hudChildren = const [],
    required this.onPause,
    required this.onResume,
    required this.onRestart,
    required this.onQuit,
  });

  @override
  State<FlameGameHost> createState() => _FlameGameHostState();
}

class _FlameGameHostState extends State<FlameGameHost> {
  // Botón compacto: los IconButton por defecto miden 48x48 y desbordan la cabecera en anchos estrechos
  Widget _compactIconButton(IconData icon, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, color: Colors.grey, size: 18),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'PUNTUACIÓN: ${widget.score}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            Flexible(
              child: Text(
                widget.title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: widget.accentColor, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 4),
            _compactIconButton(
              JuanitoModeScreen.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              () {
                HapticFeedback.selectionClick();
                setState(() {
                  JuanitoModeScreen.toggleMute();
                });
              },
            ),
            _compactIconButton(
              widget.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              () {
                HapticFeedback.selectionClick();
                if (!widget.isGameOver) {
                  widget.isPaused ? widget.onResume() : widget.onPause();
                }
              },
            ),
            _compactIconButton(Icons.logout_rounded, widget.onQuit),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: widget.accentColor.withAlpha(40)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  GameWidget(game: widget.game),
                  ...widget.hudChildren,
                  if (widget.isPaused || widget.isGameOver)
                    InGameOverlay(
                      showPause: widget.isPaused,
                      showGameOver: widget.isGameOver,
                      title: widget.isGameOver ? '¡FIN DEL JUEGO!' : 'PAUSA',
                      record: widget.record,
                      accentColor: widget.accentColor,
                      onRestart: widget.onRestart,
                      onExit: widget.onQuit,
                      onResume: widget.onResume,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
