import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/services.dart';
import 'in_game_overlay.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'shared_game_components.dart';
import '../../models/achievement.dart';

class FlappyPipe {
  double x;
  double gapY;
  final double gapHeight;
  bool passed = false;
  bool hasStar;
  bool starCollected;
  double baseY;
  double time = 0.0;

  FlappyPipe({
    required this.x,
    required this.gapY,
    required this.gapHeight,
    this.hasStar = false,
    this.starCollected = false,
  }) : baseY = gapY;
}

class FlappyGamePainter extends CustomPainter {
  final double flappyX;
  final double poopY;
  final List<FlappyPipe> pipes;
  final double width;
  final double height;
  final double flappyBgX;
  final double flappyAngle;
  final List<GameParticle> particles;
  final int highScore;
  final String equippedSkin;
  final List<FloatingText> floatingTexts;
  final bool hasShield;
  final int level;

  FlappyGamePainter({
    required this.flappyX,
    required this.poopY,
    required this.pipes,
    required this.width,
    required this.height,
    required this.flappyBgX,
    required this.flappyAngle,
    required this.particles,
    required this.highScore,
    required this.equippedSkin,
    required this.floatingTexts,
    required this.hasShield,
    required this.level,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Determinar y dibujar gradiente de fondo dinámico según el nivel
    Color skyTop;
    Color skyBottom;
    
    if (level == 1) {
      skyTop = Colors.blue[900]!;
      skyBottom = Colors.lightBlue[400]!;
    } else if (level == 2) {
      skyTop = const Color(0xFF1E1B4B); // Morado oscuro
      skyBottom = const Color(0xFFD97706); // Naranja atardecer
    } else if (level == 3) {
      skyTop = const Color(0xFF030712); // Negro espacio
      skyBottom = const Color(0xFF4C1D95); // Violeta neón
    } else {
      skyTop = const Color(0xFF450A0A); // Rojo magma
      skyBottom = const Color(0xFF0F172A); // Gris oscuro
    }

    final bgPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, height),
        [skyTop, skyBottom],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), bgPaint);

    // Dibujar estrellas lejanas (Parallax)
    final starsRand = Random(123);
    for (int i = 0; i < 20; i++) {
      double sx = (starsRand.nextDouble() * width + flappyBgX * 0.2) % width;
      double sy = starsRand.nextDouble() * height;
      double size = 0.5 + starsRand.nextDouble() * 1.0;
      double opacity = 0.2 + 0.8 * sin(DateTime.now().millisecondsSinceEpoch * 0.003 + i).abs();
      final starPaint = Paint()..color = Colors.white.withAlpha((opacity * 255).toInt());
      canvas.drawCircle(Offset(sx, sy), size, starPaint);
    }

    // Dibujar nubes en el fondo con scroll parallax
    final cloudPaint = Paint()..color = Colors.white.withAlpha(22);
    for (int i = 0; i < 3; i++) {
      double cloudX = (flappyBgX + (i * width / 1.5)) % (width + 120) - 60;
      double cloudY = 50.0 + (i * 40) % 100;
      canvas.drawCircle(Offset(cloudX, cloudY), 24, cloudPaint);
      canvas.drawCircle(Offset(cloudX + 14, cloudY - 4), 20, cloudPaint);
      canvas.drawCircle(Offset(cloudX - 14, cloudY - 4), 20, cloudPaint);
    }

    // Dibujar fondo de tuberías/mallas
    final gridPaint = Paint()
      ..color = Colors.white.withAlpha(12)
      ..strokeWidth = 0.5;
    for (double i = 0; i < width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, height), gridPaint);
    }
    for (double j = 0; j < height; j += 40) {
      canvas.drawLine(Offset(0, j), Offset(width, j), gridPaint);
    }

    // Dibujar tuberías
    final shadowPaint = Paint()
      ..color = Colors.black.withAlpha(50)
      ..style = PaintingStyle.fill;
    
    final strokePaint = Paint()
      ..color = const Color(0xFF14532D) // Verde oscuro profundo
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    for (var pipe in pipes) {
      // Sombra proyectada del tubo
      canvas.drawRect(Rect.fromLTWH(pipe.x + 5, 0, 50, pipe.gapY), shadowPaint);
      canvas.drawRect(Rect.fromLTWH(pipe.x + 5, pipe.gapY + pipe.gapHeight, 50, height - (pipe.gapY + pipe.gapHeight)), shadowPaint);

      // Gradientes metálicos 3D para la tubería y su borde (rim)
      final pipeGrad = ui.Gradient.linear(
        Offset(pipe.x, 0),
        Offset(pipe.x + 50, 0),
        [
          const Color(0xFF166534), // Verde oscuro
          const Color(0xFF22C55E), // Verde brillante
          const Color(0xFF4ADE80), // Destello blanco/verde central
          const Color(0xFF166534), // Verde oscuro
        ],
        [0.0, 0.35, 0.5, 1.0],
      );

      final rimGrad = ui.Gradient.linear(
        Offset(pipe.x - 3, 0),
        Offset(pipe.x + 53, 0),
        [
          const Color(0xFF15803D),
          const Color(0xFF4ADE80),
          const Color(0xFF86EFAC),
          const Color(0xFF166534),
        ],
        [0.0, 0.35, 0.5, 1.0],
      );

      final pipePaint = Paint()..shader = pipeGrad;
      final rimPaint = Paint()..shader = rimGrad;

      // 1. Tubería superior
      final pipeRectTop = Rect.fromLTWH(pipe.x, 0, 50, pipe.gapY);
      final rimRectTop = Rect.fromLTWH(pipe.x - 3, pipe.gapY - 18, 56, 18);
      canvas.drawRect(pipeRectTop, pipePaint);
      canvas.drawRect(rimRectTop, rimPaint);
      canvas.drawRect(pipeRectTop, strokePaint);
      canvas.drawRect(rimRectTop, strokePaint);

      // 2. Tubería inferior
      final pipeRectBottom = Rect.fromLTWH(pipe.x, pipe.gapY + pipe.gapHeight, 50, height - (pipe.gapY + pipe.gapHeight));
      final rimRectBottom = Rect.fromLTWH(pipe.x - 3, pipe.gapY + pipe.gapHeight, 56, 18);
      canvas.drawRect(pipeRectBottom, pipePaint);
      canvas.drawRect(rimRectBottom, rimPaint);
      canvas.drawRect(pipeRectBottom, strokePaint);
      canvas.drawRect(rimRectBottom, strokePaint);

      if (pipe.hasStar && !pipe.starCollected) {
        final starX = pipe.x + 27.5;
        final starY = pipe.gapY + pipe.gapHeight / 2;
        
        final glowStar = Paint()
          ..color = Colors.amber.withAlpha(80)
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 6);
        canvas.drawCircle(Offset(starX, starY), 12, glowStar);

        final starPainter = TextPainter(
          text: const TextSpan(text: '⭐', style: TextStyle(fontSize: 20)),
          textDirection: TextDirection.ltr,
        );
        starPainter.layout();
        starPainter.paint(canvas, Offset(starX - starPainter.width / 2, starY - starPainter.height / 2));
      }
    }

    if (highScore > 0) {
      final scorePaint = Paint()
        ..color = Colors.yellow[700]!.withAlpha(120)
        ..strokeWidth = 1.0;
      canvas.drawLine(Offset(0, height - 30), Offset(width, height - 30), scorePaint);
      
      final textPainter = TextPainter(
        text: TextSpan(
          text: '🏆 RÉCORD: $highScore',
          style: TextStyle(color: Colors.yellow[700]!.withAlpha(150), fontSize: 10, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(10, height - 28));
    }

    // Dibujar partículas
    for (var particle in particles) {
      canvas.save();
      canvas.translate(particle.x, particle.y);
      canvas.scale(particle.scale);
      final pPainter = TextPainter(
        text: TextSpan(
          text: particle.emoji,
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withAlpha((particle.opacity * 255).toInt()),
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      pPainter.layout();
      pPainter.paint(canvas, Offset(-pPainter.width / 2, -pPainter.height / 2));
      canvas.restore();
    }

    // Dibujar la caca rotada
    canvas.save();
    canvas.translate(flappyX, poopY);
    canvas.rotate(flappyAngle);

    // Dibujar escudo alrededor del personaje
    if (hasShield) {
      final shieldPaint = Paint()
        ..color = Colors.blueAccent.withAlpha(70)
        ..style = PaintingStyle.fill;
      final borderPaint = Paint()
        ..color = Colors.blueAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(const Offset(0, 0), 22, shieldPaint);
      canvas.drawCircle(const Offset(0, 0), 22, borderPaint);
    }

    PoopSkinDrawer.drawPoop(
      canvas,
      Offset.zero,
      32.0,
      skin: equippedSkin,
    );
    canvas.restore();

    // Dibujar textos flotantes
    for (var ft in floatingTexts) {
      canvas.save();
      final ftPainter = TextPainter(
        text: TextSpan(
          text: ft.text,
          style: TextStyle(
            color: ft.color.withAlpha((ft.opacity * 255).toInt()),
            fontSize: ft.fontSize,
            fontWeight: FontWeight.bold,
            shadows: const [
              Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1)),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      ftPainter.layout();
      ftPainter.paint(canvas, Offset(ft.x - ftPainter.width / 2, ft.y - ftPainter.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// --- TOILET JUMP ---





class FlappyPoopGame extends StatefulWidget {
  final String equippedSkin;
  final bool hasInitialSoapShield;
  final bool hasLifeInsurance;
  final Function(int) onGameOver;
  final Function(int) onAddKcoins;
  final VoidCallback onUnlockAchievement;
  final int highScore;
  final Function(int) onSaveHighScore;
  final AchievementCategory? activeBuffCategory;

  const FlappyPoopGame({
    Key? key,
    required this.equippedSkin,
    required this.hasInitialSoapShield,
    required this.hasLifeInsurance,
    required this.onGameOver,
    required this.onAddKcoins,
    required this.onUnlockAchievement,
    required this.highScore,
    required this.onSaveHighScore,
    this.activeBuffCategory,
  }) : super(key: key);

  @override
  _FlappyPoopGameState createState() => _FlappyPoopGameState();
}

class _FlappyPoopGameState extends State<FlappyPoopGame> {
  bool _isPausedLocal = false;
  double _shakeX = 0.0;
  double _shakeY = 0.0;
  Color? _flashColor;

  void _triggerFlash(Color color, int duration) {
    int ticks = duration;
    Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted || ticks <= 0) {
        setState(() {
          _flashColor = null;
        });
        timer.cancel();
        return;
      }
      setState(() {
        _flashColor = color.withAlpha((color.alpha * (ticks / duration)).toInt());
        ticks--;
      });
    });
  }

  void _triggerShake(double intensity, int duration) {
    int ticks = duration;
    final rand = Random();
    Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted || ticks <= 0) {
        setState(() {
          _shakeX = 0.0;
          _shakeY = 0.0;
        });
        timer.cancel();
        return;
      }
      setState(() {
        _shakeX = (rand.nextDouble() - 0.5) * intensity;
        _shakeY = (rand.nextDouble() - 0.5) * intensity;
        ticks--;
      });
    });
  }
  int _level = 1;
  int _score = 0;
  final double _flappyX = 115.0;
  double _flappyY = 200;
  double _flappyVelocity = 0;
  final List<FlappyPipe> _flappyPipes = [];
  Timer? _flappyTimer;
  bool _isFlappyGameOver = false;
  double _flappyBgX = 0;
  bool _hasFlappyShield = false;
  
  final List<GameParticle> _particles = [];
  final List<FloatingText> _floatingTexts = [];
  DateTime _lastTickTime = DateTime.now();

  double _gameWidth = 0;
  double _gameHeight = 0;

  @override
  void dispose() {
    _flappyTimer?.cancel();
    super.dispose();
  }

  void startGame() {
    _score = 0;
    _level = 1;
    _flappyY = 200;
    _flappyVelocity = 0;
    _flappyPipes.clear();
    _isFlappyGameOver = false;
    _flappyBgX = 0;
    _particles.clear();
    _floatingTexts.clear();
    _hasFlappyShield = widget.hasInitialSoapShield || widget.hasLifeInsurance || widget.activeBuffCategory == AchievementCategory.games;
    _lastTickTime = DateTime.now();

    widget.onUnlockAchievement();

    _spawnFlappyPipe(450);
    _spawnFlappyPipe(670);

    _flappyTimer?.cancel();
    _flappyTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      _updateFlappyStep();
    });
  }

  void _spawnFlappyPipe(double startX) {
    final rand = Random();
    final gapY = 80.0 + rand.nextDouble() * 120.0;
    _flappyPipes.add(FlappyPipe(
      x: startX,
      gapY: gapY,
      gapHeight: 125.0,
      hasStar: rand.nextDouble() < 0.40,
    ));
  }

  double _calculateDeltaTime() {
    final now = DateTime.now();
    final dt = now.difference(_lastTickTime).inMilliseconds / 1000.0;
    _lastTickTime = now;
    return dt.clamp(0.01, 0.1);
  }

  void _updateFlappyStep() {
    final dt = _calculateDeltaTime();
    if (_isPausedLocal || _isFlappyGameOver) return;
    if (_gameWidth < 100 || _gameHeight < 100) return;

    for (int i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      p.x += p.vx * dt * 30;
      p.y += p.vy * dt * 30;
      p.opacity -= dt;
      if (p.opacity <= 0) _particles.removeAt(i);
    }
    for (int i = _floatingTexts.length - 1; i >= 0; i--) {
      final ft = _floatingTexts[i];
      ft.y -= ft.vy * dt * 30;
      ft.opacity -= dt;
      if (ft.opacity <= 0) _floatingTexts.removeAt(i);
    }

    setState(() {
      double gravity = 0.36;
      if (widget.activeBuffCategory == AchievementCategory.locations) gravity *= 0.90;
      _flappyVelocity += gravity * dt * 33.3;
      _flappyY += _flappyVelocity * dt * 33.3;
      _flappyBgX = (_flappyBgX - 0.7 * dt * 33.3) % _gameWidth;

      if (Random().nextInt(100) < 25) {
        String particleEmoji = widget.equippedSkin == '💩' 
            ? ['💨', '🦠', '🪰', '🤢', '💨', '🦠'][Random().nextInt(6)]
            : (widget.equippedSkin == '🧻' ? '🫧' : '✨');
        _particles.add(GameParticle(
          x: _flappyX - 10,
          y: _flappyY + (Random().nextDouble() * 10 - 5),
          vx: -1.8 - Random().nextDouble() * 1.5,
          vy: Random().nextDouble() * 0.8 - 0.4,
          emoji: particleEmoji,
          scale: 0.4 + Random().nextDouble() * 0.4,
          lifeTime: 8 + Random().nextInt(6),
        ));
      }

      if (_flappyY < 15) _flappyY = 15;
      if (_flappyY > _gameHeight - 15) {
        _handleFlappyGameOver();
        return;
      }

      for (int i = _flappyPipes.length - 1; i >= 0; i--) {
        final pipe = _flappyPipes[i];
        pipe.x -= 4.8 * dt * 33.3;

        if (_level >= 2) {
          pipe.time += dt * (1.2 + _level * 0.2);
          pipe.gapY = pipe.baseY + sin(pipe.time) * (20.0 + _level * 6.0);
        }

        const cacaRadius = 14.0;
        final cacaX = _flappyX;

        bool hitTop = pipe.x < cacaX + cacaRadius &&
            pipe.x + 55.0 > cacaX - cacaRadius &&
            _flappyY - cacaRadius < pipe.gapY;
        bool hitBottom = pipe.x < cacaX + cacaRadius &&
            pipe.x + 55.0 > cacaX - cacaRadius &&
            _flappyY + cacaRadius > pipe.gapY + pipe.gapHeight;

        if (hitTop || hitBottom) {
          if (_hasFlappyShield) {
            _hasFlappyShield = false;
            HapticFeedback.heavyImpact();
            _triggerFlash(Colors.blueAccent.withAlpha(80), 8);
            _triggerShake(4.0, 10);
            _spawnParticles(cacaX, _flappyY, '🫧', 15);
            _spawnFloatingText(cacaX, _flappyY - 20, '¡ESCUDO ROTO! 🫧', Colors.blue);
            pipe.passed = true;
            pipe.x = -100;
          } else {
            _handleFlappyGameOver();
            break;
          }
        }

        if (pipe.hasStar && !pipe.starCollected) {
          final starX = pipe.x + 27.5;
          final starY = pipe.gapY + pipe.gapHeight / 2;
          final dist = sqrt(pow(cacaX - starX, 2) + pow(_flappyY - starY, 2));
          if (dist < 26.0) {
            pipe.starCollected = true;
            HapticFeedback.mediumImpact();
            _spawnParticles(starX, starY, '⭐', 8, speed: 4.0);
            _spawnFloatingText(starX, starY - 15, '+5 K\$', Colors.amber, fontSize: 16.0);
            widget.onAddKcoins(5);
          }
        }

        if (!pipe.passed && pipe.x + 27.5 < cacaX) {
          pipe.passed = true;
          _score += 1;
          HapticFeedback.lightImpact();
          _triggerFlash(Colors.greenAccent.withAlpha(20), 4);
          _spawnParticles(cacaX + 20, pipe.gapY + pipe.gapHeight / 2, '⭐', 8, speed: 5.0);
          _spawnFloatingText(cacaX + 20, pipe.gapY + pipe.gapHeight / 2 - 20, '+1', Colors.deepPurpleAccent, fontSize: 18);
          widget.onSaveHighScore(_score);
          if (_score >= 25) widget.onUnlockAchievement();

          int newLevel = 1 + (_score ~/ 8);
          if (newLevel != _level) {
            _level = newLevel;
            _triggerFlash(Colors.white.withAlpha(150), 10);
            _triggerShake(8.0, 15);
            _spawnFloatingText(_gameWidth / 2, _gameHeight / 2, '¡NIVEL $_level! 🚀', Colors.orangeAccent, fontSize: 32.0);
          }
        }

        if (pipe.x < -60) {
          _flappyPipes.removeAt(i);
          _spawnFlappyPipe(_gameWidth + 50);
        }
      }
    });
  }

  void _spawnParticles(double x, double y, String emoji, int count, {double speed = 1.0}) {
    final rand = Random();
    for (int i = 0; i < count; i++) {
      _particles.add(GameParticle(
        x: x,
        y: y,
        vx: (rand.nextDouble() * 4 - 2) * speed,
        vy: (rand.nextDouble() * 4 - 2) * speed,
        emoji: emoji,
        scale: 0.5 + rand.nextDouble() * 0.5,
        lifeTime: 10 + rand.nextInt(10),
      ));
    }
  }

  void _spawnFloatingText(double x, double y, String text, Color color, {double fontSize = 14.0}) {
    _floatingTexts.add(FloatingText(
      text: text,
      x: x,
      y: y,
      color: color,
      fontSize: fontSize,
      vx: 0.0,
      vy: 1.5,
      lifeTime: 60,
    ));
  }

  void _handleFlappyGameOver() {
    HapticFeedback.vibrate();
    _triggerFlash(Colors.redAccent.withAlpha(120), 10);
    _triggerShake(8.0, 15);
    _spawnParticles(_flappyX, _flappyY, '💥', 12);
    _flappyTimer?.cancel();
    setState(() {
      _isFlappyGameOver = true;
    });
  }

  void _onFlappyTap() {
    if (_isFlappyGameOver) return;
    HapticFeedback.selectionClick();
    setState(() {
      double jumpForce = -5.8;
      if (widget.activeBuffCategory == AchievementCategory.stats) jumpForce -= 1.0;
      _flappyVelocity = jumpForce;
      _spawnParticles(_flappyX, _flappyY + 10, '💨', 3, speed: 2.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _gameWidth = constraints.maxWidth;
        _gameHeight = constraints.maxHeight;

        if (_flappyTimer == null && !_isFlappyGameOver && !_isPausedLocal) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _flappyTimer == null) {
              startGame();
            }
          });
        }

        return Transform.translate(
          offset: Offset(_shakeX, _shakeY),
          child: GestureDetector(
            onTap: _onFlappyTap,
            behavior: HitTestBehavior.opaque,
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  child: CustomPaint(
                    painter: FlappyGamePainter(
                      flappyX: _flappyX,
                      poopY: _flappyY,
                      pipes: _flappyPipes,
                      width: _gameWidth,
                      height: _gameHeight,
                      flappyBgX: _flappyBgX,
                      flappyAngle: (_flappyVelocity * 0.08).clamp(-0.4, 1.1),
                      particles: _particles,
                      highScore: widget.highScore,
                      equippedSkin: widget.equippedSkin,
                      floatingTexts: _floatingTexts,
                      hasShield: _hasFlappyShield,
                      level: _level,
                    ),
                  ),
                ),
                if (_flashColor != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(color: _flashColor),
                    ),
                  ),
                if (_isFlappyGameOver)
                  InGameOverlay(
                    showPause: false,
                    showGameOver: _isFlappyGameOver,
                    title: 'FLAPPY POOP',
                    record: widget.highScore,
                    accentColor: Colors.deepPurpleAccent,
                    onRestart: () {
                      setState(() {
                        startGame();
                      });
                    },
                    onExit: () => widget.onGameOver(_score),
                    onResume: () {},
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
