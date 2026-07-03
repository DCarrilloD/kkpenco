import 'package:flutter/material.dart';
import 'flame_game_host.dart';
import 'flame_games/flame_flappy_poop.dart' show FlappyPoopFlameGame;
import '../../models/achievement.dart';

class FlappyPoopGame extends StatefulWidget {
  final int highScore;
  final String equippedSkin;
  final bool hasInitialSoapShield;
  final bool hasLifeInsurance;
  final AchievementCategory? activeBuffCategory;
  final Function(int) onGameOver;
  final Function(int) onAddKcoins;
  final Function(int) onSaveHighScore;

  const FlappyPoopGame({
    super.key,
    required this.highScore,
    required this.equippedSkin,
    required this.hasInitialSoapShield,
    required this.hasLifeInsurance,
    required this.onGameOver,
    required this.onAddKcoins,
    required this.onSaveHighScore,
    this.activeBuffCategory,
  });

  @override
  State<FlappyPoopGame> createState() => _FlappyPoopGameState();
}

class _FlappyPoopGameState extends State<FlappyPoopGame> {
  late FlappyPoopFlameGame _flameGame;

  int _score = 0;
  int _level = 1;
  bool _isPaused = false;
  bool _isGameOver = false;

  @override
  void initState() {
    super.initState();
    _initFlameGame();
  }

  void _initFlameGame() {
    _flameGame = FlappyPoopFlameGame(
      equippedSkin: widget.equippedSkin,
      hasInitialSoapShield: widget.hasInitialSoapShield,
      hasLifeInsurance: widget.hasLifeInsurance,
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
      onLevelChanged: (newLevel) {
        Future.microtask(() {
          if (!mounted) return;
          setState(() => _level = newLevel);
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
      _level = 1;
      _initFlameGame();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FlameGameHost(
      game: _flameGame,
      title: 'FLAPPY POOP 💩',
      accentColor: Colors.deepPurpleAccent,
      backgroundColor: const Color(0xFF0F172A),
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
          left: 0,
          right: 0,
          child: Center(
            child: Text(
              'NIVEL $_level',
              style: TextStyle(
                color: Colors.deepPurpleAccent[100],
                fontSize: 14,
                fontWeight: FontWeight.bold,
                shadows: const [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(2, 2))],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
