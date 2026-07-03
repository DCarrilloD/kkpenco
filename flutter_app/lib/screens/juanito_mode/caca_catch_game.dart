import 'package:flutter/material.dart';
import 'flame_game_host.dart';
import 'flame_games/flame_caca_catch.dart' show CacaCatchFlameGame;
import '../../models/achievement.dart';

class CacaCatchGame extends StatefulWidget {
  final int highScore;
  final String equippedSkin;
  final bool hasImprovedMagnet;
  final bool hasInitialSoapShield;
  final bool hasExtraLife;
  final bool hasFeverMagnet;
  final AchievementCategory? activeBuffCategory;
  final Function(int) onGameOver;
  final Function(int) onAddKcoins;
  final Function(int) onSaveHighScore;

  const CacaCatchGame({
    super.key,
    required this.highScore,
    required this.equippedSkin,
    required this.hasImprovedMagnet,
    required this.hasInitialSoapShield,
    required this.hasExtraLife,
    required this.hasFeverMagnet,
    required this.onGameOver,
    required this.onAddKcoins,
    required this.onSaveHighScore,
    this.activeBuffCategory,
  });

  @override
  State<CacaCatchGame> createState() => _CacaCatchGameState();
}

class _CacaCatchGameState extends State<CacaCatchGame> {
  late CacaCatchFlameGame _flameGame;

  int _score = 0;
  int _lives = 3;
  bool _isFever = false;
  double _feverProgress = 0.0;
  bool _isPaused = false;
  bool _isGameOver = false;

  @override
  void initState() {
    super.initState();
    _initFlameGame();
  }

  void _initFlameGame() {
    _flameGame = CacaCatchFlameGame(
      equippedSkin: widget.equippedSkin,
      hasImprovedMagnet: widget.hasImprovedMagnet,
      hasInitialSoapShield: widget.hasInitialSoapShield,
      hasExtraLife: widget.hasExtraLife,
      hasFeverMagnet: widget.hasFeverMagnet,
      activeBuffCategory: widget.activeBuffCategory,
      onGameOver: (finalScore) {
        Future.microtask(() {
          if (!mounted) return;
          widget.onSaveHighScore(finalScore);
          setState(() {
            _isGameOver = true;
            _score = finalScore;
          });
        });
      },
      onAddKcoins: widget.onAddKcoins,
      onScoreChanged: (newScore) {
        Future.microtask(() {
          if (!mounted) return;
          setState(() => _score = newScore);
        });
      },
      onLivesChanged: (newLives) {
        Future.microtask(() {
          if (!mounted) return;
          setState(() => _lives = newLives);
        });
      },
      onFeverChanged: (isFever, progress) {
        // Se dispara cada frame durante la fiebre: solo reconstruir cuando cambia algo visible
        final quantized = (progress.clamp(0.0, 1.0) * 20).round() / 20;
        if (isFever == _isFever && quantized == _feverProgress) return;
        Future.microtask(() {
          if (!mounted) return;
          setState(() {
            _isFever = isFever;
            _feverProgress = quantized;
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

  void _restartGame() {
    setState(() {
      _isGameOver = false;
      _isPaused = false;
      _score = 0;
      _lives = 3;
      _isFever = false;
      _feverProgress = 0.0;
      _initFlameGame();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FlameGameHost(
      game: _flameGame,
      title: 'CACA CATCH 🚽',
      accentColor: Colors.amber,
      backgroundColor: const Color(0xFF0D0D0D),
      score: _score,
      record: widget.highScore,
      isPaused: _isPaused,
      isGameOver: _isGameOver,
      onPause: _pauseGame,
      onResume: _resumeGame,
      onRestart: _restartGame,
      onQuit: _quitGame,
      hudChildren: [
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isFever)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🔥 FIEBRE',
                        style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 110,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _feverProgress,
                            minHeight: 5,
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                const Spacer(),
              Text(
                '❤️' * _lives,
                style: const TextStyle(fontSize: 14, shadows: [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(2, 2))]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
