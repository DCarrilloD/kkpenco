import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';
import 'flame_games/flame_poop_invaders.dart';
import 'in_game_overlay.dart';
import '../../models/achievement.dart';
import '../juanito_mode_screen.dart';

class PoopInvadersGame extends StatefulWidget {
  final int highScore;
  final String equippedSkin;
  final bool hasTripleShot;
  final bool hasBurstShot;
  final Function(int) onGameOver;
  final Function(int) onAddKcoins;
  final Function(int) onSaveHighScore;
  final AchievementCategory? activeBuffCategory;

  const PoopInvadersGame({
    super.key,
    required this.highScore,
    required this.equippedSkin,
    required this.hasTripleShot,
    required this.hasBurstShot,
    required this.onGameOver,
    required this.onAddKcoins,
    required this.onSaveHighScore,
    this.activeBuffCategory,
  });

  @override
  State<PoopInvadersGame> createState() => _PoopInvadersGameState();
}

class _PoopInvadersGameState extends State<PoopInvadersGame> {
  late PoopInvadersFlameGame _flameGame;

  int _score = 0;
  int _lives = 5;
  int _wave = 1;
  double _gameTimeSeconds = 0.0;
  bool _isPaused = false;
  bool _isGameOver = false;

  @override
  void initState() {
    super.initState();
    _initFlameGame();
  }

  void _initFlameGame() {
    _flameGame = PoopInvadersFlameGame(
      equippedSkin: widget.equippedSkin,
      hasInitialTripleShot: widget.hasTripleShot,
      hasInitialBurstShot: widget.hasBurstShot,
      activeBuffCategory: widget.activeBuffCategory,
      onGameOver: (finalScore) {
        Future.microtask(() {
          if (!mounted) return;
          setState(() {
            _isGameOver = true;
            _score = finalScore;
            widget.onSaveHighScore(_score);
          });
        });
      },
      onAddKcoins: widget.onAddKcoins,
      onScoreChanged: (newScore) {
        Future.microtask(() {
          if (!mounted) return;
          setState(() {
            _score = newScore;
          });
        });
      },
      onLivesChanged: (newLives) {
        Future.microtask(() {
          if (!mounted) return;
          setState(() {
            _lives = newLives;
          });
        });
      },
      onWaveChanged: (newWave) {
        Future.microtask(() {
          if (!mounted) return;
          setState(() {
            _wave = newWave;
          });
        });
      },
      onTimeChanged: (newTime) {
        Future.microtask(() {
          if (!mounted) return;
          setState(() {
            _gameTimeSeconds = newTime;
          });
        });
      },
    );
  }

  void _pauseGame() {
    setState(() => _isPaused = true);
    _flameGame.pauseEngine();
  }

  void _resumeGame() {
    setState(() => _isPaused = false);
    _flameGame.resumeEngine();
  }

  void _quitGame() {
    widget.onGameOver(_score);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('PUNTUACIÓN: $_score', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const Text('POOP INVADERS 👽', style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    JuanitoModeScreen.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    color: Colors.grey,
                    size: 18,
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      JuanitoModeScreen.toggleMute();
                    });
                  },
                ),
                IconButton(
                  icon: Icon(_isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, color: Colors.grey, size: 18),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    if (!_isGameOver) {
                      _isPaused ? _resumeGame() : _pauseGame();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.grey, size: 18),
                  onPressed: _quitGame,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF030712), // Espacio profundo
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.greenAccent.withAlpha(40)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  // 1. Capa base: Flame Game Widget
                  GameWidget(
                    game: _flameGame,
                  ),

                  // 2. HUD Superior Flotante
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Izquierda: Tiempo
                        Text(
                          'TIEMPO: ${_gameTimeSeconds.toInt()}s',
                          style: TextStyle(color: Colors.amber[700], fontSize: 12, fontWeight: FontWeight.bold, shadows: const [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(2, 2))]),
                        ),
                        // Centro: Oleada
                        Text(
                          'OLEADA: $_wave',
                          style: TextStyle(color: Colors.greenAccent[400], fontSize: 14, fontWeight: FontWeight.bold, shadows: const [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(2, 2))]),
                        ),
                        // Derecha: Vidas
                        Text(
                          '❤️' * _lives,
                          style: const TextStyle(fontSize: 14, shadows: [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(2, 2))]),
                        ),
                      ],
                    ),
                  ),

                  // 3. Menús de Overlay (Pausa y Game Over)
                  if (_isPaused || _isGameOver)
                    InGameOverlay(
                      showPause: _isPaused,
                      showGameOver: _isGameOver,
                      title: _isGameOver ? '¡FIN DEL JUEGO!' : 'PAUSA',
                      record: widget.highScore,
                      accentColor: Colors.greenAccent,
                      onRestart: () {
                        setState(() {
                          _isGameOver = false;
                          _isPaused = false;
                          _score = 0;
                          _lives = 5;
                          _wave = 1;
                          _gameTimeSeconds = 0.0;
                          _initFlameGame();
                        });
                      },
                      onExit: _quitGame,
                      onResume: _resumeGame,
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
