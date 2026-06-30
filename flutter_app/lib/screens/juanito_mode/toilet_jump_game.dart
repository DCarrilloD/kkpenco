import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'in_game_overlay.dart';
import 'shared_game_components.dart';
import 'in_game_overlay.dart';

class ToiletJumpGame extends StatefulWidget {
  final Function(int score, int coins) onGameOver;
  final String equippedSkin;

  const ToiletJumpGame({
    super.key,
    required this.onGameOver,
    required this.equippedSkin,
  });

  @override
  State<ToiletJumpGame> createState() => _ToiletJumpGameState();
}

class _ToiletJumpGameState extends State<ToiletJumpGame> {
  int _score = 0;
  int _coinsEarned = 0;
  bool _isGameOver = false;
  bool _isPausedLocalLocal = false;


  double _jumpX = 150;
  double _jumpY = 300;
  double _jumpVx = 0;
  double _jumpVy = 0;
  double _cameraY = 0;
  
  double _gameWidth = 300;
  double _gameHeight = 400;
  
  bool _hasInitialSpring = false;
  bool _hasInitialSoapShield = false;
  int _shakeTicks = 0;
  int _level = 1;
  double _shakeX = 0;
  double _shakeY = 0;
  Color? _flashColor;
  DateTime _lastTickTime = DateTime.now();
  final List<GameParticle> _particles = [];
  final List<FloatingText> _floatingTexts = [];
  bool randPercent(int percent) => Random().nextInt(100) < percent;
  
  void _onGameStarted() {}
  double _calculateDeltaTime() {
    final now = DateTime.now();
    final dt = now.difference(_lastTickTime).inMilliseconds / 1000.0;
    _lastTickTime = now;
    return dt;
  }
  void _updateJuicyEffects(double dt) {
    // Actualizar partículas
    for (int i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      p.x += p.vx * dt * 30;
      p.y += p.vy * dt * 30;
      p.opacity -= dt;
      if (p.opacity <= 0) _particles.removeAt(i);
    }
    // Actualizar textos flotantes
    for (int i = _floatingTexts.length - 1; i >= 0; i--) {
      final ft = _floatingTexts[i];
      ft.y -= ft.vy * dt * 30;
      ft.opacity -= dt;
      if (ft.opacity <= 0) _floatingTexts.removeAt(i);
    }
  }
  void _updateToiletJump(Timer t) => _updateToiletJumpStep();
  
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

  void _spawnParticles(double x, double y, String emoji, int count, {double speed = 1.0}) {
    final rand = Random();
    for (int i = 0; i < count; i++) {
      _particles.add(GameParticle(
        x: x,
        y: y,
        vx: (rand.nextDouble() - 0.5) * 4 * speed,
        vy: (rand.nextDouble() - 0.5) * 4 * speed,
        emoji: emoji,
        scale: 0.5 + rand.nextDouble() * 0.5,
        lifeTime: 10 + rand.nextInt(10),
      ));
    }
  }

  void _spawnFloatingText(double x, double y, String text, Color color) {
    _floatingTexts.add(FloatingText(
      text: text,
      x: x,
      y: y,
      color: color,
      fontSize: 14.0,
      vx: 0.0,
      vy: 1.5,
      lifeTime: 60,
    ));
  }

  void _saveHighScore(String game, int score) {}

  void _performDoubleJump() {
    if (_isGameOver || _isPausedLocalLocal) return;
    if (_hasJetpack || _hasBalloon) return;
    if (_availableDoubleJumps > 0) {
      setState(() {
        _jumpVy = -9.2;
        _availableDoubleJumps--;
        _cacaScaleY = 0.55;
        _cacaScaleX = 1.45;
        _triggerFlash(Colors.cyanAccent.withAlpha(25), 5);
        _spawnParticles(_jumpX, _jumpY + 12, '💨', 10);
        _spawnFloatingText(_jumpX, _jumpY - 20, '¡DOBLE SALTO! 💨', Colors.cyanAccent);
      });
      HapticFeedback.mediumImpact();
    }
  }
  List<JumpPlatform> _jumpPlatforms = [];
  List<BacteriaEnemy> _jumpBacterias = [];
  Timer? _toiletJumpTimer;
  double _maxHeightReached = 0;
  double _cacaScaleX = 1.0;
  double _cacaScaleY = 1.0;
  bool _hasJetpack = false;
  int _jetpackTicksRemaining = 0;
  bool _hasBalloon = false;
  int _balloonTicksRemaining = 0;
  int _availableDoubleJumps = 1;

  @override
  void initState() {
    super.initState();
    _startToiletJump();
  }

  @override
  void didUpdateWidget(ToiletJumpGame oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _stopToiletJump();
    super.dispose();
  }

  void _startToiletJump() {
    _onGameStarted();
    _stopToiletJump();
    setState(() {
      _score = 0;
      _level = 1;
      _jumpX = 150;
      _jumpY = 280;
      _jumpVx = 0;
      
      // Aplicar super impulso inicial si se ha comprado
      _jumpVy = _hasInitialSpring ? -15.5 : -8.0;
      _hasInitialSpring = false; // consumido
      
      _cameraY = 0;
      _isGameOver = false;
      _maxHeightReached = 0;
      _jumpPlatforms.clear();
      _jumpBacterias.clear();
      _particles.clear();
      _shakeTicks = 0;
      _flashColor = null;
      _cacaScaleX = 1.0;
      _cacaScaleY = 1.0;
      
      // Aplicar jetpack inicial si se ha comprado
      _hasJetpack = _hasInitialSoapShield;
      _jetpackTicksRemaining = _hasInitialSoapShield ? 60 : 0;
      _hasInitialSoapShield = false; // consumido
      
      _hasBalloon = false;
      _balloonTicksRemaining = 0;
      _availableDoubleJumps = 1;

      // Variables de juego profesional
      _lastTickTime = DateTime.now();
      _floatingTexts.clear();
      _isPausedLocalLocal = false;
    });

    // Achievements removed in refactor
    _jumpPlatforms.add(JumpPlatform(x: 120, y: 350, width: 70, type: PlatformType.normal));

    // Generar plataformas iniciales escalonadas
    for (int i = 0; i < 9; i++) {
      _spawnJumpPlatform(300.0 - (i * 65.0));
    }

    _toiletJumpTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      _updateToiletJumpStep();
    });
  }

  void _spawnJumpPlatform(double targetY) {
    final rand = Random();
    const pWidth = 55.0;
    final pX = rand.nextDouble() * (_gameWidth - pWidth - 20) + 10;
    final rVal = rand.nextDouble();
    PlatformType type = PlatformType.normal;

    if (rVal < 0.12 && targetY < 150) {
      type = PlatformType.fragile;
    } else if (rVal < 0.28 && targetY < 200) {
      type = PlatformType.moving;
    } else if (rVal < 0.38 && targetY < -100) {
      type = PlatformType.superSpring;
    }

    ItemType item = ItemType.none;
    if (type == PlatformType.normal && targetY < 250) {
      final iVal = rand.nextDouble();
      if (iVal < 0.10) {
        item = ItemType.spring;
      } else if (iVal < 0.14 && targetY < -100) {
        item = ItemType.jetpack;
      } else if (iVal < 0.22 && targetY < 0) {
        item = ItemType.balloon;
      }
    }

    _jumpPlatforms.add(JumpPlatform(
      x: pX,
      y: targetY,
      width: pWidth,
      type: type,
      item: item,
    ));

    // A├▒adir bacteria flotante
    if (targetY < 100 && rand.nextDouble() < 0.15) {
      _jumpBacterias.add(BacteriaEnemy(
        x: rand.nextDouble() * (_gameWidth - 40) + 10,
        y: targetY - 35.0,
        vx: (rand.nextBool() ? 1.0 : -1.0) * (1.2 + rand.nextDouble() * 1.0),
        width: 30,
        height: 30,
      ));
    }
  }

  void _stopToiletJump() {
    _toiletJumpTimer?.cancel();
    _toiletJumpTimer = null;
  }

  void _updateToiletJumpStep() {
    final dt = _calculateDeltaTime();
    if (_isPausedLocalLocal || _isGameOver) return;
    if (_gameWidth < 100 || _gameHeight < 100) return;

    _updateJuicyEffects(dt);

    setState(() {
      // Squash & Stretch recuperaci├│n gradual
      _cacaScaleX += (1.0 - _cacaScaleX) * 0.15 * dt * 33.3;
      _cacaScaleY += (1.0 - _cacaScaleY) * 0.15 * dt * 33.3;

      // Recuperaci├│n el├ística de resortes de plataformas
      for (var p in _jumpPlatforms) {
        p.scaleY += (1.0 - p.scaleY) * 0.15 * dt * 33.3;
      }

      // L├│gica de Globo de Gas
      if (_hasBalloon) {
        _balloonTicksRemaining--;
        _jumpVy = -6.5; // Ascenso suave y seguro
        if (randPercent(15)) {
          _spawnParticles(_jumpX, _jumpY + 12, '🎈', 1, speed: 1.0);
        }
        if (_balloonTicksRemaining <= 0) {
          _hasBalloon = false;
        }
      } else if (_hasJetpack) {
        _jetpackTicksRemaining--;
        _jumpVy = -13.0;
        // Partículas propulsión agua
        _spawnParticles(_jumpX, _jumpY + 12, '💦', 2, speed: 5.0);
        _triggerShake(2.0, 1);
        if (_jetpackTicksRemaining <= 0) {
          _hasJetpack = false;
        }
      } else {
        // Gravedad normal
        _jumpVy += 0.32 * dt * 33.3;
      }

      // Trail visual para skins premium en Toilet Jump
      if (randPercent(20)) {
        String trailEmoji = widget.equippedSkin == '🌈'
            ? ['🔴', '🟠', '🟡', '🟢', '🔵', '🟣'][Random().nextInt(6)]
            : (widget.equippedSkin == '🦄' ? '✨' : '');
        if (trailEmoji.isNotEmpty) {
          _particles.add(GameParticle(
            x: _jumpX,
            y: _jumpY + 12,
            vx: Random().nextDouble() * 1.0 - 0.5,
            vy: 1.0 + Random().nextDouble() * 1.5,
            emoji: trailEmoji,
            scale: 0.4 + Random().nextDouble() * 0.4,
            lifeTime: 8 + Random().nextInt(6),
          ));
        }
      }

      _jumpY += _jumpVy * dt * 33.3;
      _jumpX += _jumpVx * dt * 33.3;

      // Amortiguar movimiento X
      _jumpVx *= pow(0.85, dt * 33.3);

      // Salir por los bordes e ingresar por el otro lado (wrap-around)
      if (_jumpX < 5) _jumpX = _gameWidth - 5;
      if (_jumpX > _gameWidth - 5) _jumpX = 5;

      // Movimiento de plataformas m├│viles
      for (var p in _jumpPlatforms) {
        if (p.type == PlatformType.moving) {
          p.x += p.vx * dt * 33.3;
          if (p.x < 10 || p.x + p.width > _gameWidth - 10) {
            p.vx = -p.vx;
          }
        }
      }

      // Movimiento y oscilación sinusoidal de bacterias flotantes
      for (var b in _jumpBacterias) {
        double currentVx = b.vx;
        if (_level >= 3) {
          double direction = (_jumpX - b.x).sign;
          currentVx = b.vx + direction * 0.8;
          currentVx = currentVx.clamp(-2.5, 2.5);
        }
        b.x += currentVx * dt * 33.3;
        b.time += dt * (5.0 + _level); // velocidad de la oscilación dinámica
        b.y = b.baseY + sin(b.time) * (15.0 + _level * 3);

        if (b.x < 10 || b.x + b.width > _gameWidth - 10) {
          b.vx = -b.vx;
        }

        // Estela de humo ocasional morado
        if (randPercent(12)) {
          _particles.add(GameParticle(
            x: b.x + b.width / 2,
            y: b.y + b.height / 2,
            vx: Random().nextDouble() * 0.6 - 0.3,
            vy: Random().nextDouble() * 0.6 + 0.2,
            emoji: '💨',
            scale: 0.5,
            lifeTime: 8,
          ));
        }
      }

      // Colisión con bacterias flotantes
      for (var b in _jumpBacterias) {
        if (b.dead) continue;

        // Caja de colisión simple
        bool overlapX = (_jumpX - (b.x + b.width / 2)).abs() < 22;
        bool overlapY = (_jumpY - (b.y + b.height / 2)).abs() < 22;

        if (overlapX && overlapY) {
          // Si cae encima de ella, la mata y rebota
          if (_jumpVy > 0 && _jumpY + 10 < b.y + b.height / 2) {
            b.dead = true;
            _jumpVy = -9.0;
            _availableDoubleJumps = 1;
            _score += 100;
            _cacaScaleY = 0.55;
            _cacaScaleX = 1.45;
            _spawnParticles(b.x + b.width / 2, b.y + b.height / 2, '💀', 8);
            _spawnFloatingText(b.x + b.width / 2, b.y + b.height / 2 - 20, '+100 💀', Colors.orangeAccent);
            _saveHighScore('toilet_jump', _score);
            HapticFeedback.mediumImpact();
          } else {
            // Si choca por debajo/lados y no tiene Jetpack ni Globo, muere
            if (!_hasJetpack && !_hasBalloon) {
              _handleToiletJumpGameOver();
              return;
            }
          }
        }
      }

      // Colisión con plataformas (solo cayendo y sin jetpack ni globo)
      if (_jumpVy > 0 && !_hasJetpack && !_hasBalloon) {
        const cacaRadius = 15.0;
        final cacaBottom = _jumpY + cacaRadius;

        for (int i = 0; i < _jumpPlatforms.length; i++) {
          final p = _jumpPlatforms[i];
          if (_jumpX + cacaRadius > p.x && 
              _jumpX - cacaRadius < p.x + p.width && 
              cacaBottom > p.y && 
              cacaBottom < p.y + 15) {
            
            if (p.type == PlatformType.fragile) {
              p.broken = true; // Se rompe al tocarla
              _spawnParticles(p.x + p.width / 2, p.y, '🧩', 6, speed: 2.0);
              HapticFeedback.vibrate();
            } else if (p.type == PlatformType.superSpring) {
              _jumpVy = -16.5; // Salto súper gigante
              _cacaScaleY = 0.3;
              _cacaScaleX = 1.7;
              _triggerFlash(Colors.redAccent.withAlpha(40), 6);
              _triggerShake(3.0, 8);
              _spawnParticles(p.x + p.width / 2, p.y, '🔥', 10, speed: 4.0);
              _spawnFloatingText(_jumpX, _jumpY - 20, '¡SUPER IMPULSO! 🔥', Colors.redAccent);
              HapticFeedback.heavyImpact();
            } else {
              _jumpVy = -8.5; // rebote normal
              _cacaScaleY = 0.6;
              _cacaScaleX = 1.4;
              HapticFeedback.lightImpact();

              // Si tiene objetos sobre ella
              if (p.item == ItemType.spring && !p.itemUsed) {
                p.itemUsed = true;
                p.scaleY = 0.4; // COMPRIMIR RESORTE
                _jumpVy = -14.5; // súper impulso
                _cacaScaleY = 0.4;
                _cacaScaleX = 1.6;
                _triggerFlash(Colors.amberAccent.withAlpha(30), 5);
                _spawnParticles(_jumpX, _jumpY + 10, '⚡', 8);
                _spawnFloatingText(_jumpX, _jumpY - 20, '¡SÚPER IMPULSO! ⚡', Colors.amberAccent);
                HapticFeedback.heavyImpact();
              } else if (p.item == ItemType.jetpack && !p.itemUsed) {
                p.itemUsed = true;
                _hasJetpack = true;
                _jetpackTicksRemaining = 70; // ~2 segundos
                _triggerFlash(Colors.blueAccent.withAlpha(60), 8);
                _spawnParticles(_jumpX, _jumpY, '💦', 12);
                _spawnFloatingText(_jumpX, _jumpY - 20, '¡JETPACK DE AGUA! 💦', Colors.blueAccent);
                HapticFeedback.heavyImpact();
              } else if (p.item == ItemType.balloon && !p.itemUsed) {
                p.itemUsed = true;
                _hasBalloon = true;
                _balloonTicksRemaining = 130; // ~4 segundos
                _triggerFlash(Colors.greenAccent.withAlpha(60), 8);
                _spawnParticles(_jumpX, _jumpY, '🎈', 12);
                _spawnFloatingText(_jumpX, _jumpY - 20, '¡GLOBO DE HELIO! 🎈', Colors.greenAccent);
                HapticFeedback.heavyImpact();
              }
              _availableDoubleJumps = 1;
            }
            break;
          }
        }
      }

      // Cámara dinámica persigue al personaje hacia arriba
      if (_jumpY < _cameraY + 180) {
        double diff = (_cameraY + 180) - _jumpY;
        _cameraY -= diff;
        _maxHeightReached += diff;

        // Sumar puntos por altura recorrida
        final currentHeightScore = (_maxHeightReached ~/ 5).toInt();
        if (currentHeightScore > _score) {
          _score = currentHeightScore;
          _saveHighScore('toilet_jump', _score);

          int newLevel = 1;
          if (_score > 1000) {
            newLevel = 4;
          } else if (_score > 500) {
            newLevel = 3;
          } else if (_score > 200) {
            newLevel = 2;
          }

          if (newLevel != _level) {
            _level = newLevel;
            _triggerFlash(Colors.white.withAlpha(150), 10);
            _triggerShake(8.0, 15);
            _spawnFloatingText(_gameWidth / 2, _jumpY - 60, '¡NIVEL $_level! 🚀', Colors.orangeAccent);
          }
        }
      }

      // Eliminar plataformas viejas abajo e ir generando nuevas arriba
      for (int i = _jumpPlatforms.length - 1; i >= 0; i--) {
        final p = _jumpPlatforms[i];
        if (p.y > _cameraY + _gameHeight + 40) {
          _jumpPlatforms.removeAt(i);
          // Spawn arriba
          double topPlatformY = _jumpPlatforms.map((p) => p.y).reduce(min);
          _spawnJumpPlatform(topPlatformY - 65.0);
        }
      }

      // Eliminar bacterias viejas
      for (int i = _jumpBacterias.length - 1; i >= 0; i--) {
        final b = _jumpBacterias[i];
        if (b.y > _cameraY + _gameHeight + 40) {
          _jumpBacterias.removeAt(i);
        }
      }

      // Caer fuera de cámara significa Game Over
      if (_jumpY > _cameraY + _gameHeight + 10) {
        _handleToiletJumpGameOver();
      }
    });
  }

  void _handleToiletJumpGameOver() {
    HapticFeedback.vibrate();
    _triggerFlash(Colors.redAccent.withAlpha(120), 10);
    _triggerShake(8.0, 15);
    _spawnParticles(_jumpX, _jumpY, '💀', 12);
    _stopToiletJump();
    setState(() {
      _isGameOver = true;
    });
  }


  void _onToiletJumpLeftTap() {
    setState(() {
      _jumpVx = -7.5;
    });
  }

  void _onToiletJumpRightTap() {
    setState(() {
      _jumpVx = 7.5;
    });
  }

  // ==========================================
  // --- FIN DE PARTIDA & FIN DE SESIÓN ---
  // ==========================================


  void _handleExit() {
    _stopToiletJump();
    widget.onGameOver(_score, _coinsEarned);
  }

  // ==========================================
  // --- CONSTRUCCIÓN DE LA INTERFAZ ---
  // ==========================================
  @override
Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('PUNTUACIÓN: $_score', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const Text('TOILET JUMP 🚽jump', style: TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold)),
            Row(
              children: [
                IconButton(
                  icon: Icon(_isPausedLocalLocal ? Icons.play_arrow_rounded : Icons.pause_rounded, color: Colors.grey, size: 18),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      if (!_isGameOver) {
                        _isPausedLocalLocal = !_isPausedLocalLocal;
                        if (!_isPausedLocalLocal) {
                          _toiletJumpTimer ??= Timer.periodic(const Duration(milliseconds: 16), (t) => _updateToiletJumpStep());
                        }
                      }
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.grey, size: 18),
                  onPressed: _handleExit,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _gameWidth = constraints.maxWidth;
              _gameHeight = constraints.maxHeight;

              if (_gameWidth > 50 && _gameHeight > 50) {
                if (_toiletJumpTimer == null && !_isGameOver && !_isPausedLocalLocal) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _toiletJumpTimer == null) {
                      _startToiletJump();
                    }
                  });
                }
              }

              return Transform.translate(
                offset: Offset(_shakeX, _shakeY),
                child: GestureDetector(
                  onTap: _performDoubleJump,
                  onPanUpdate: (details) {
                    if (_isPausedLocalLocal || _isGameOver) return;
                    setState(() {
                      _jumpX = (_jumpX + details.delta.dx).clamp(15.0, _gameWidth - 15.0);
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D0D0D),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orangeAccent.withAlpha(40)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        children: [
                          // Canvas del juego
                          Positioned.fill(
                            child: CustomPaint(
                              painter: ToiletJumpPainter(
                                jumpX: _jumpX,
                                jumpY: _jumpY,
                                cameraY: _cameraY,
                                platforms: _jumpPlatforms,
                                bacterias: _jumpBacterias,
                                particles: _particles,
                                width: _gameWidth,
                                height: _gameHeight,
                                scaleX: _cacaScaleX,
                                scaleY: _cacaScaleY,
                                hasJetpack: _hasJetpack,
                                hasBalloon: _hasBalloon,
                                equippedSkin: widget.equippedSkin,
                                floatingTexts: _floatingTexts,
                              ),
                            ),
                          ),
                          // Botones de control lateral opcionales (taps de soporte)
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            width: 60,
                            child: GestureDetector(
                              onTap: _onToiletJumpLeftTap,
                              behavior: HitTestBehavior.translucent,
                              child: Container(),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            bottom: 0,
                            width: 60,
                            child: GestureDetector(
                              onTap: _onToiletJumpRightTap,
                              behavior: HitTestBehavior.translucent,
                              child: Container(),
                            ),
                          ),
                          if (_flashColor != null)
                            Positioned.fill(
                              child: Container(color: _flashColor),
                            ),
                          if (_isPausedLocalLocal || _isGameOver)
                            InGameOverlay(
                              showPause: _isPausedLocalLocal,
                              showGameOver: _isGameOver,
                              title: 'TOILET JUMP',
                              record: 0,
                              accentColor: Colors.orangeAccent,
                              onRestart: _startToiletJump,
                              onExit: _handleExit,
                              onResume: () => setState(() => _isPausedLocalLocal = false),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

}

enum PlatformType { normal, moving, fragile, superSpring }
enum ItemType { none, spring, jetpack, balloon }

class JumpPlatform {
  double x;
  double y;
  double width;
  final PlatformType type;
  double vx = 2.0;
  bool broken = false;
  ItemType item;
  bool itemUsed = false;
  double scaleY = 1.0;

  JumpPlatform({
    required this.x,
    required this.y,
    required this.width,
    required this.type,
    this.item = ItemType.none,
  });
}

class BacteriaEnemy {
  double x;
  double y;
  double vx;
  double width;
  double height;
  double time = 0.0;
  double baseY = 0.0;
  bool dead = false;

  BacteriaEnemy({
    required this.x,
    required this.y,
    required this.vx,
    required this.width,
    required this.height,
  }) {
    baseY = y;
  }
}

class ToiletJumpPainter extends CustomPainter {

  final double jumpX;

  final double jumpY;

  final double cameraY;

  final List<JumpPlatform> platforms;

  final List<BacteriaEnemy> bacterias;

  final List<GameParticle> particles;

  final double width;

  final double height;
  bool dead = false;

  final double scaleX;

  final double scaleY;

  final bool hasJetpack;

  final bool hasBalloon;

  final String equippedSkin;

  final List<FloatingText> floatingTexts;



  ToiletJumpPainter({

    required this.jumpX,

    required this.jumpY,

    required this.cameraY,

    required this.platforms,

    required this.bacterias,

    required this.particles,

    required this.width,

    required this.height,

    required this.scaleX,
    required this.scaleY,
    required this.hasJetpack,
    required this.hasBalloon,
    required this.equippedSkin,
    required this.floatingTexts,
  });

  void _drawBacteriaVector(Canvas canvas, Offset center, double size) {
    final double half = size / 2;
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(center.dx - 3, center.dy - 3),
        half,
        [Colors.purpleAccent[200]!, Colors.purple[800]!],
      );
    
    final path = Path();
    final int points = 10;
    final double angleStep = (2 * pi) / points;
    final timeMs = DateTime.now().millisecondsSinceEpoch;
    
    for (int i = 0; i < points; i++) {
      double angle = i * angleStep;
      double wave = sin(timeMs * 0.015 + i) * 2.0;
      double r = half + (i % 2 == 0 ? 4.0 + wave : -1.5);
      double px = center.dx + cos(angle) * r;
      double py = center.dy + sin(angle) * r;
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
    
    final eyePaint = Paint()..color = Colors.redAccent;
    final pupilPaint = Paint()..color = Colors.white;
    
    final leftEyeCenter = Offset(center.dx - half * 0.35, center.dy - half * 0.1);
    final rightEyeCenter = Offset(center.dx + half * 0.35, center.dy - half * 0.1);
    
    canvas.drawCircle(leftEyeCenter, 4.0, eyePaint);
    canvas.drawCircle(leftEyeCenter - const Offset(0.8, 0.8), 1.2, pupilPaint);
    
    canvas.drawCircle(rightEyeCenter, 4.0, eyePaint);
    canvas.drawCircle(rightEyeCenter - const Offset(0.8, 0.8), 1.2, pupilPaint);
    
    final eyebrowPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    
    canvas.drawLine(Offset(center.dx - half * 0.55, center.dy - half * 0.4), Offset(center.dx - half * 0.1, center.dy - half * 0.2), eyebrowPaint);
    canvas.drawLine(Offset(center.dx + half * 0.55, center.dy - half * 0.4), Offset(center.dx + half * 0.1, center.dy - half * 0.2), eyebrowPaint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final heightClimbed = -cameraY;
    
    Color skyTop;
    Color skyBottom;
    
    if (heightClimbed < 2000) {
      final t = (heightClimbed / 2000.0).clamp(0.0, 1.0);
      skyTop = Color.lerp(const Color(0xFF1E2836), const Color(0xFF0D1017), t)!;
      skyBottom = Color.lerp(const Color(0xFFE28A3B), const Color(0xFF1A1B24), t)!;
    } else if (heightClimbed < 5000) {
      final t = ((heightClimbed - 2000.0) / 3000.0).clamp(0.0, 1.0);
      skyTop = Color.lerp(const Color(0xFF0D1017), const Color(0xFF020202), t)!;
      skyBottom = Color.lerp(const Color(0xFF1A1B24), const Color(0xFF050505), t)!;
    } else {
      skyTop = const Color(0xFF010101);
      skyBottom = const Color(0xFF030303);
    }
    
    final skyRect = Rect.fromLTWH(0, 0, width, height);
    final skyGradient = LinearGradient(
      colors: [skyTop, skyBottom],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
    final skyPaint = Paint()..shader = skyGradient.createShader(skyRect);
    canvas.drawRect(skyRect, skyPaint);

    final starsRand = Random(42);
    for (int i = 0; i < 35; i++) {
      double sx = starsRand.nextDouble() * width;
      double sy = (starsRand.nextDouble() * height - (cameraY * 0.4)) % height;
      double size = 0.5 + starsRand.nextDouble() * 1.5;
      double opacity = 0.3 + 0.7 * sin(DateTime.now().millisecondsSinceEpoch * 0.003 + i).abs();
      
      final starPaint = Paint()..color = Colors.white.withAlpha((opacity * 255).toInt());
      canvas.drawCircle(Offset(sx, sy), size, starPaint);
    }

    canvas.save();
    canvas.translate(0, -cameraY);

    final normalPaint = Paint()..color = Colors.greenAccent[700]!..style = PaintingStyle.fill;
    final movingPaint = Paint()..color = Colors.blueAccent[400]!..style = PaintingStyle.fill;
    final fragilePaint = Paint()..color = Colors.brown[600]!..style = PaintingStyle.fill;
    final superSpringPaint = Paint()..color = Colors.redAccent[400]!..style = PaintingStyle.fill;

    for (var p in platforms) {
      if (p.broken) continue;

      Paint pPaint = normalPaint;
      if (p.type == PlatformType.moving) {
        pPaint = movingPaint;
      } else if (p.type == PlatformType.fragile) {
        pPaint = fragilePaint;
      } else if (p.type == PlatformType.superSpring) {
        pPaint = superSpringPaint;
      }

      final rect = Rect.fromLTWH(p.x, p.y, p.width, 10);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(5));
      canvas.drawRRect(rrect, pPaint);

      final borderPaint = Paint()..color = Colors.white24..style = PaintingStyle.stroke..strokeWidth = 1.0;
      canvas.drawRRect(rrect, borderPaint);

      if (p.item != ItemType.none && !p.itemUsed) {
        canvas.save();
        canvas.translate(p.x + p.width / 2, p.y - 4);

        if (p.item == ItemType.spring) {
          canvas.scale(1.0, p.scaleY);
          final springPaint = Paint()..color = Colors.grey[400]!..strokeWidth = 2.0..style = PaintingStyle.stroke;
          final Path springPath = Path();
          springPath.moveTo(-6, 0);
          springPath.lineTo(6, -2);
          springPath.lineTo(-5, -5);
          springPath.lineTo(5, -8);
          springPath.lineTo(-6, -11);
          springPath.lineTo(6, -13);
          canvas.drawPath(springPath, springPaint);
          canvas.drawRect(Rect.fromLTWH(-8, -15, 16, 2.5), Paint()..color = Colors.redAccent);
        } else if (p.item == ItemType.jetpack) {
          final rocketPaint = Paint()..color = Colors.grey[500]!;
          canvas.drawRect(const Rect.fromLTWH(-5, -14, 10, 14), rocketPaint);
          // Simplified replacement for drawConeAndCone since it's not a native Canvas method
          final conePath = Path()..moveTo(0, -18)..lineTo(5, -14)..lineTo(-5, -14)..close();
          canvas.drawPath(conePath, Paint()..color = Colors.redAccent);
          canvas.drawRect(const Rect.fromLTWH(-7, -8, 2, 6), Paint()..color = Colors.orangeAccent);
          canvas.drawRect(const Rect.fromLTWH(5, -8, 2, 6), Paint()..color = Colors.orangeAccent);
        } else {
          final double gWidth = 12.0;
          final double gHeight = 16.0;
          final double gy = -24.0;
          final balloonPaint = Paint()..shader = ui.Gradient.radial(Offset(-2, gy - 3), gWidth, [Colors.red[300]!, Colors.red[700]!]);
          canvas.drawOval(Rect.fromCenter(center: Offset(0, gy), width: gWidth, height: gHeight), balloonPaint);
          final knotPath = Path()..moveTo(-2, gy + gHeight / 2)..lineTo(2, gy + gHeight / 2)..lineTo(0, gy + gHeight / 2 + 2)..close();
          canvas.drawPath(knotPath, Paint()..color = Colors.red[900]!);
          final linePaint = Paint()..color = Colors.white54..strokeWidth = 0.8;
          canvas.drawLine(Offset(0, gy + gHeight / 2 + 2), const Offset(0, 0), linePaint);
        }
        canvas.restore();
      }
    }

    for (var b in bacterias) {
      if (b.dead) continue;
      _drawBacteriaVector(canvas, Offset(b.x + b.width / 2, b.y + b.height / 2), 24);
    }

    for (var particle in particles) {
      canvas.save();
      canvas.translate(particle.x, particle.y);
      canvas.scale(particle.scale);
      final pPainter = TextPainter(
        text: TextSpan(text: particle.emoji, style: TextStyle(fontSize: 16, color: Colors.white.withAlpha((particle.opacity * 255).toInt()))),
        textDirection: TextDirection.ltr,
      );
      pPainter.layout();
      pPainter.paint(canvas, Offset(-pPainter.width / 2, -pPainter.height / 2));
      canvas.restore();
    }

    canvas.save();
    canvas.translate(jumpX, jumpY);
    canvas.scale(scaleX, scaleY);

    if (hasJetpack) {
      final jetpackPaint = Paint()..color = Colors.blueAccent.withAlpha(60)..style = PaintingStyle.fill;
      canvas.drawCircle(const Offset(0, 0), 20, jetpackPaint);
    }

    if (hasBalloon) {
      final linePaint = Paint()..color = Colors.white70..strokeWidth = 1.0;
      canvas.drawLine(const Offset(0, -10), const Offset(12, -32), linePaint);
      final double gWidth = 14.0;
      final double gHeight = 18.0;
      final double gx = 12.0;
      final double gy = -42.0;
      final balloonPaint = Paint()..shader = ui.Gradient.radial(Offset(gx - 2, gy - 3), gWidth, [Colors.red[300]!, Colors.red[700]!]);
      canvas.drawOval(Rect.fromCenter(center: Offset(gx, gy), width: gWidth, height: gHeight), balloonPaint);
      final knotPath = Path()..moveTo(gx - 2, gy + gHeight / 2)..lineTo(gx + 2, gy + gHeight / 2)..lineTo(gx, gy + gHeight / 2 + 2)..close();
      canvas.drawPath(knotPath, Paint()..color = Colors.red[900]!);
    }

    PoopSkinDrawer.drawPoop(canvas, Offset.zero, 30.0, skin: equippedSkin);
    canvas.restore();

    for (var ft in floatingTexts) {
      canvas.save();
      final ftPainter = TextPainter(
        text: TextSpan(
          text: ft.text,
          style: TextStyle(color: ft.color.withAlpha((ft.opacity * 255).toInt()), fontSize: ft.fontSize, fontWeight: FontWeight.bold, shadows: const [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1))]),
        ),
        textDirection: TextDirection.ltr,
      );
      ftPainter.layout();
      ftPainter.paint(canvas, Offset(ft.x - ftPainter.width / 2, ft.y - ftPainter.height / 2));
      canvas.restore();
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}