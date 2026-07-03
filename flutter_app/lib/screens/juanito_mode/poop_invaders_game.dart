import 'package:flutter/material.dart';
import 'flame_game_host.dart';
import 'flame_games/flame_poop_invaders.dart';
import '../../models/achievement.dart';

class PoopInvadersGame extends StatefulWidget {
  final int highScore;
  final String equippedSkin;
  final bool hasTripleShot;
  final bool hasBurstShot;
  final bool hasLifeInsurance;
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
    this.hasLifeInsurance = false,
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
  int _gameTimeSeconds = 0;
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
      hasInitialShield: widget.hasLifeInsurance,
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
      onWaveChanged: (newWave) {
        Future.microtask(() {
          if (!mounted) return;
          setState(() => _wave = newWave);
        });
      },
      onTimeChanged: (newTime) {
        // Se dispara cada frame: solo reconstruir cuando cambia el segundo entero
        final seconds = newTime.toInt();
        if (seconds == _gameTimeSeconds) return;
        Future.microtask(() {
          if (!mounted) return;
          setState(() => _gameTimeSeconds = seconds);
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
      _lives = 5;
      _wave = 1;
      _gameTimeSeconds = 0;
      _initFlameGame();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FlameGameHost(
      game: _flameGame,
      title: 'POOP INVADERS 👽',
      accentColor: Colors.greenAccent,
      backgroundColor: const Color(0xFF030712),
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
              Text(
                'TIEMPO: ${_gameTimeSeconds}s',
                style: TextStyle(color: Colors.amber[700], fontSize: 12, fontWeight: FontWeight.bold, shadows: const [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(2, 2))]),
              ),
              Text(
                'OLEADA: $_wave',
                style: TextStyle(color: Colors.greenAccent[400], fontSize: 14, fontWeight: FontWeight.bold, shadows: const [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(2, 2))]),
              ),
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
