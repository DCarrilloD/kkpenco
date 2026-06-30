import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class InGameOverlay extends StatelessWidget {
  final bool showPause;
  final bool showGameOver;
  final String title;
  final int record;
  final Color accentColor;
  final VoidCallback onRestart;
  final VoidCallback onExit;
  final VoidCallback onResume;

  const InGameOverlay({
    super.key,
    required this.showPause,
    required this.showGameOver,
    required this.title,
    required this.record,
    required this.accentColor,
    required this.onRestart,
    required this.onExit,
    required this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    if (!showPause && !showGameOver) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            color: Colors.black.withAlpha(showPause ? 140 : 180),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      showPause ? Icons.pause_circle_filled_rounded : Icons.sentiment_very_dissatisfied_rounded,
                      color: showPause ? Colors.amberAccent : Colors.redAccent,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      showPause ? 'JUEGO EN PAUSA' : '¡FIN DE PARTIDA!',
                      style: TextStyle(
                        color: showPause ? Colors.white : Colors.redAccent,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: TextStyle(color: accentColor.withAlpha(200), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Column(
                        children: [
                          const Text('TU RÉCORD ACTUAL', style: TextStyle(color: Colors.white70, fontSize: 10)),
                          const SizedBox(height: 4),
                          Text(
                            '$record',
                            style: TextStyle(color: accentColor, fontSize: 28, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (showPause)
                      ElevatedButton.icon(
                        onPressed: onResume,
                        icon: const Icon(Icons.play_arrow_rounded, color: Colors.black),
                        label: const Text('REANUDAR', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amberAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                    if (showGameOver)
                      ElevatedButton.icon(
                        onPressed: onRestart,
                        icon: const Icon(Icons.replay_rounded, color: Colors.black),
                        label: const Text('JUGAR DE NUEVO', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: onExit,
                      icon: const Icon(Icons.exit_to_app_rounded, size: 16, color: Colors.white70),
                      label: const Text('SALIR AL MENÚ', style: TextStyle(color: Colors.white70)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
