import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'in_game_overlay.dart';
import 'shared_game_components.dart';
import '../../models/achievement.dart';

class GameStar {
  double x;
  double y;
  double speed;
  double size;
  GameStar({required this.x, required this.y, required this.speed, required this.size});
}

class InvaderLaser {
  double x;
  double y;
  double vy;
  double vx;
  bool fromPlayer;
  String type; // 'normal', 'meteor', 'lightning', 'acid', 'acid_sub'

  InvaderLaser({
    required this.x,
    required this.y,
    required this.vy,
    this.vx = 0.0,
    required this.fromPlayer,
    this.type = 'normal',
  });
}

class InvaderEnemy {
  double x;
  double y;
  double vx;
  int hp;
  int maxHp;
  String type; // 'normal', 'fast', 'boss'
  String bossType; // 'fire', 'electric', 'acid'
  String visualType; // 'poop', 'bacteria', 'alien'
  double time = 0.0;

  InvaderEnemy({
    required this.x,
    required this.y,
    required this.vx,
    required this.hp,
    this.type = 'normal',
    this.bossType = 'none',
    this.visualType = 'poop',
  }) : maxHp = hp;
}

class InvaderItem {
  double x;
  double y;
  double vy;
  String type; // 'triple', 'burst', 'shield', 'life'

  InvaderItem({
    required this.x,
    required this.y,
    required this.vy,
    required this.type,
  });
}

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
  // Game variables
  double _invadersShipX = 0.5;
  double _invadersShipY = 0.86;
  final List<InvaderLaser> _invaderLasers = [];
  final List<InvaderEnemy> _invaderEnemies = [];
  final List<InvaderItem> _invaderItems = [];
  final List<GameStar> _stars = [];
  Timer? _poopInvadersTimer;
  int _invadersFireCooldown = 0;
  bool _isInvadersGameOver = false;
  int _invadersWave = 1;

  int _score = 0;
  bool _isPausedLocalLocal = false;
  int _lives = 5;
  int _tripleShotTicks = 0;
  int _burstShotTicks = 0;
  bool _hasShield = false;
  
  double _shipTilt = 0.0;
  double _ufoTimer = 0.0;

  double _shakeX = 0.0;
  double _shakeY = 0.0;
  Color? _flashColor;
  final List<GameParticle> _particles = [];
  final List<FloatingText> _floatingTexts = [];

  double _gameWidth = 320;
  double _gameHeight = 480;
  DateTime _lastTickTime = DateTime.now();

  // Boss Progression variables
  double _gameTimeSeconds = 0.0;
  bool _isBossActive = false;
  int _nextBossIndex = 1; // Jefe 1 a los 30s, Jefe 2 a los 75s (30+45), Jefe 3 a los 135s (75+60)...
  final List<int> _bossSpawnTimes = [30, 75, 135, 210, 295, 390, 495, 610];
  double _bossAttackTimer = 0.0;

  @override
  void initState() {
    super.initState();
    _startPoopInvaders();
  }

  @override
  void dispose() {
    _poopInvadersTimer?.cancel();
    super.dispose();
  }

  void _startPoopInvaders() {
    _poopInvadersTimer?.cancel();
    setState(() {
      _score = 0;
      _lives = 5;
      if (widget.activeBuffCategory == AchievementCategory.games) _lives++;
      _isPausedLocalLocal = false;
      _invadersWave = 1;
      _gameTimeSeconds = 0.0;
      _invadersShipX = 0.5;
      _invadersShipY = 0.86;
      _invaderLasers.clear();
      _invaderEnemies.clear();
      _invaderItems.clear();
      _particles.clear();
      _floatingTexts.clear();
      _stars.clear();
      
      final rand = Random();
      for (int i = 0; i < 40; i++) {
        _stars.add(GameStar(
          x: rand.nextDouble(),
          y: rand.nextDouble(),
          speed: 0.1 + rand.nextDouble() * 0.4,
          size: 0.5 + rand.nextDouble() * 2.0,
        ));
      }

      _isInvadersGameOver = false;
      _isBossActive = false;
      _nextBossIndex = 1;
      _tripleShotTicks = 0;
      _burstShotTicks = 0;
      _hasShield = false;
      _shipTilt = 0.0;
      _ufoTimer = 0.0;
      _lastTickTime = DateTime.now();
      _spawnInvaderWave();
    });

    _poopInvadersTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      _updateInvadersStep();
    });
  }

  void _spawnInvaderWave() {
    _invaderEnemies.clear();
    _invaderLasers.clear();
    _invaderItems.clear();
    
    _triggerFlash(Colors.white.withAlpha(120), 8);
    _triggerShake(6.0, 10);
    _spawnFloatingText(0.5, 0.45, '¡OLEADA $_invadersWave! 👾', Colors.greenAccent, fontSize: 24.0);

    // Spawn de bacterias o aliens para la oleada normal
    int cols = 5;
    int rows = 2;
    double speed = 0.008 + _invadersWave * 0.003;
    bool isAlienWave = _nextBossIndex > 1; // Si ya derrotaste al primer jefe, son Aliens

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        _invaderEnemies.add(InvaderEnemy(
          x: 0.16 + c * 0.17,
          y: 0.12 + r * 0.12,
          vx: c % 2 == 0 ? speed : -speed,
          hp: isAlienWave ? 2 : 1,
          type: (r == 0 && _invadersWave > 1) ? 'fast' : 'normal',
          visualType: isAlienWave ? 'alien' : 'bacteria',
        ));
      }
    }
  }

  void _spawnBoss(int bossNumber) {
    // Alertas y efectos visuales de llegada del Boss
    _triggerFlash(Colors.redAccent.withAlpha(140), 12);
    _triggerShake(12.0, 25);
    _spawnFloatingText(0.5, 0.45, '⚠️ ¡ALERTA DE JEFE FINAL! ⚠️', Colors.redAccent, fontSize: 24.0);

    // Destruir todas las bacterias comunes activas en una explosión visual
    for (var enemy in _invaderEnemies) {
      _spawnParticles(enemy.x, enemy.y, '💥', 8);
    }
    _invaderEnemies.clear();
    _invaderLasers.clear();
    _isBossActive = true;

    // Determinar el tipo de Boss
    String bType = 'fire';
    int maxHp = 30 + bossNumber * 10;
    if (widget.activeBuffCategory == AchievementCategory.social) {
      maxHp = (maxHp * 0.85).toInt();
    }
    if (bossNumber == 2) {
      bType = 'electric';
    } else if (bossNumber == 3) {
      bType = 'acid';
    } else {
      // Rotar entre los 3 tipos para jefes posteriores
      final types = ['fire', 'electric', 'acid'];
      bType = types[(bossNumber - 1) % 3];
    }

    _invaderEnemies.add(InvaderEnemy(
      x: 0.5,
      y: 0.18,
      vx: 0.012,
      hp: maxHp,
      type: 'boss',
      bossType: bType,
    ));
  }

  void _firePlayerLaser() {
    HapticFeedback.selectionClick();
    double speed = 0.024;
    if (_tripleShotTicks > 0) {
      _invaderLasers.add(InvaderLaser(x: _invadersShipX, y: _invadersShipY - 0.05, vy: -speed, fromPlayer: true));
      _invaderLasers.add(InvaderLaser(x: _invadersShipX - 0.05, y: _invadersShipY - 0.04, vy: -speed, vx: -0.005, fromPlayer: true));
      _invaderLasers.add(InvaderLaser(x: _invadersShipX + 0.05, y: _invadersShipY - 0.04, vy: -speed, vx: 0.005, fromPlayer: true));
    } else {
      _invaderLasers.add(InvaderLaser(x: _invadersShipX, y: _invadersShipY - 0.05, vy: -speed, fromPlayer: true));
    }
  }

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
        x: x * _gameWidth,
        y: y * _gameHeight,
        vx: (rand.nextDouble() - 0.5) * 5 * speed,
        vy: (rand.nextDouble() - 0.5) * 5 * speed,
        emoji: emoji,
        scale: 0.5 + rand.nextDouble() * 0.5,
        lifeTime: 12 + rand.nextInt(10),
      ));
    }
  }

  void _spawnFloatingText(double x, double y, String text, Color color, {double fontSize = 14.0}) {
    _floatingTexts.add(FloatingText(
      text: text,
      x: x * _gameWidth,
      y: y * _gameHeight,
      color: color,
      fontSize: fontSize,
      vx: 0.0,
      vy: 1.2,
      lifeTime: 45,
    ));
  }

  void _updateInvadersStep() {
    final dt = _calculateDeltaTime();
    if (_isPausedLocalLocal || _isInvadersGameOver) return;
    if (_gameWidth < 100 || _gameHeight < 100) return;

    // Actualizar tiempo de juego
    setState(() {
      _gameTimeSeconds += dt;
      _ufoTimer += dt;
      
      for (var star in _stars) {
        star.y += star.speed * dt;
        if (star.y > 1.0) {
          star.y = 0.0;
          star.x = Random().nextDouble();
        }
      }
      
      _shipTilt *= 0.88; // Decaimiento suave de la inclinación
      
      // Comprobar si corresponde spawnear un Boss
      if (_nextBossIndex - 1 < _bossSpawnTimes.length &&
          _gameTimeSeconds >= _bossSpawnTimes[_nextBossIndex - 1] &&
          !_isBossActive) {
        _spawnBoss(_nextBossIndex);
        _nextBossIndex++;
      }
    });

    // Actualizar efectos visuales de partículas
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
      // Cooldown de Powerups
      if (_tripleShotTicks > 0) _tripleShotTicks--;
      if (_burstShotTicks > 0) _burstShotTicks--;

      // Disparo automático del jugador
      if (_invadersFireCooldown > 0) {
        _invadersFireCooldown--;
      } else {
        _invadersFireCooldown = _burstShotTicks > 0 ? 5 : 12;
        _firePlayerLaser();
      }

      // Mover y actualizar Láseres
      for (int i = _invaderLasers.length - 1; i >= 0; i--) {
        final laser = _invaderLasers[i];
        double currentVy = laser.vy;
        if (!laser.fromPlayer && widget.activeBuffCategory == AchievementCategory.locations) {
          currentVy *= 0.90;
        }
        laser.x += laser.vx * dt * 33.3;
        laser.y += currentVy * dt * 33.3;

        // Comportamientos especiales de proyectiles enemigos
        if (!laser.fromPlayer) {
          if (laser.type == 'lightning') {
            // Zigzagueo eléctrico
            laser.vx = sin(DateTime.now().millisecondsSinceEpoch * 0.02) * 0.014;
          } else if (laser.type == 'acid' && laser.y >= 0.5) {
            // División del proyectil de ácido en 2 hijos diagonales
            _invaderLasers.removeAt(i);
            _invaderLasers.add(InvaderLaser(x: laser.x, y: laser.y, vy: 0.012, vx: -0.006, fromPlayer: false, type: 'acid_sub'));
            _invaderLasers.add(InvaderLaser(x: laser.x, y: laser.y, vy: 0.012, vx: 0.006, fromPlayer: false, type: 'acid_sub'));
            _spawnParticles(laser.x, laser.y, '🧪', 5);
            continue;
          }
        }

        if (laser.y < 0.0 || laser.y > 1.0 || laser.x < 0.0 || laser.x > 1.0) {
          _invaderLasers.removeAt(i);
          continue;
        }

        if (laser.fromPlayer) {
          // Colisión con enemigos
          for (int j = _invaderEnemies.length - 1; j >= 0; j--) {
            final enemy = _invaderEnemies[j];
            double range = enemy.type == 'boss' ? 0.18 : 0.09;
            bool hitX = (laser.x - enemy.x).abs() < range;
            bool hitY = (laser.y - enemy.y).abs() < range;

            if (hitX && hitY) {
              _invaderLasers.removeAt(i);
              enemy.hp--;
              _spawnParticles(enemy.x, enemy.y, '💥', 3, speed: 2.0);
              
              if (enemy.hp <= 0) {
                if (enemy.type == 'boss') {
                  _isBossActive = false;
                  int reward = 500 + (_nextBossIndex - 1) * 100;
                  _score += reward;
                  _spawnParticles(enemy.x, enemy.y, '🔥', 20, speed: 4.0);
                  _spawnFloatingText(enemy.x, enemy.y, '¡JEFE DEFEATED! +$reward 🏆', Colors.greenAccent, fontSize: 18);
                  widget.onAddKcoins(80);
                  
                  _triggerShake(18.0, 35);
                  _triggerFlash(Colors.white.withAlpha(200), 15);
                  
                  // Volver a spawnear bacterias normales tras derrotar al Boss
                  _spawnInvaderWave();
                } else if (enemy.type == 'ufo') {
                  int reward = 250;
                  _score += reward;
                  widget.onAddKcoins(50);
                  _spawnParticles(enemy.x, enemy.y, '⭐', 15, speed: 3.5);
                  _spawnFloatingText(enemy.x, enemy.y, '+$reward 💰', Colors.yellowAccent);
                  
                  String pType = ['triple', 'burst', 'shield', 'life'][Random().nextInt(4)];
                  _invaderItems.add(InvaderItem(x: enemy.x, y: enemy.y, vy: 0.006, type: pType));
                } else {
                  int reward = 15;
                  _score += reward;
                  _spawnParticles(enemy.x, enemy.y, '💀', 8, speed: 3.5);
                  _spawnFloatingText(enemy.x, enemy.y, '+$reward 💀', Colors.greenAccent);
                }
                
                _invaderEnemies.removeAt(j);
                
                widget.onSaveHighScore(_score);

                // Soltar powerup con probabilidad
                final rand = Random();
                double dropChance = widget.activeBuffCategory == AchievementCategory.calendar ? 0.38 : 0.28;
                if (enemy.type == 'boss' || (enemy.type != 'ufo' && rand.nextDouble() < dropChance)) {
                  String pType = ['triple', 'burst', 'shield', 'life'][rand.nextInt(4)];
                  _invaderItems.add(InvaderItem(
                    x: enemy.x,
                    y: enemy.y,
                    vy: 0.006,
                    type: pType,
                  ));
                }
              }
              break;
            }
          }
        } else {
          // Colisión de proyectil enemigo con el jugador
          double collisionRadius = laser.type == 'meteor' ? 0.12 : 0.07;
          bool hitX = (laser.x - _invadersShipX).abs() < collisionRadius;
          bool hitY = (laser.y - _invadersShipY).abs() < collisionRadius;
          if (hitX && hitY) {
            _invaderLasers.removeAt(i);
            
            // Efecto especial si es Meteorito
            if (laser.type == 'meteor') {
              _spawnParticles(laser.x, laser.y, '🔥', 15, speed: 3.0);
            }

            if (_hasShield) {
              _hasShield = false;
              _triggerFlash(Colors.blueAccent.withAlpha(90), 8);
              _triggerShake(4.0, 10);
              _spawnParticles(_invadersShipX, _invadersShipY, '🫧', 10);
              _spawnFloatingText(_invadersShipX, _invadersShipY - 0.05, '¡ESCUDO ROTO! 🫧', Colors.blueAccent);
              HapticFeedback.heavyImpact();
            } else {
              _lives--;
              _triggerFlash(Colors.red.withAlpha(120), 10);
              _triggerShake(8.0, 15);
              _spawnParticles(_invadersShipX, _invadersShipY, '💔', 12);
              _spawnFloatingText(_invadersShipX, _invadersShipY - 0.05, '💔 -1 Vida', Colors.redAccent);
              HapticFeedback.vibrate();
              if (_lives <= 0) {
                _isInvadersGameOver = true;
                _poopInvadersTimer?.cancel();
              }
            }
          }
        }
      }

      // Mover y actualizar Items de Powerups
      for (int i = _invaderItems.length - 1; i >= 0; i--) {
        final item = _invaderItems[i];
        item.y += item.vy * dt * 33.3;

        if (item.y > 1.0) {
          _invaderItems.removeAt(i);
          continue;
        }

        // Colisión con el jugador
        bool hitX = (item.x - _invadersShipX).abs() < 0.08;
        bool hitY = (item.y - _invadersShipY).abs() < 0.08;
        if (hitX && hitY) {
          _invaderItems.removeAt(i);
          HapticFeedback.heavyImpact();
          _triggerFlash(Colors.amber.withAlpha(60), 6);
          _spawnParticles(_invadersShipX, _invadersShipY, '⭐', 15);

          if (item.type == 'triple') {
            _tripleShotTicks = 200; // ~6 segundos
            _spawnFloatingText(_invadersShipX, _invadersShipY - 0.06, '¡TRIPLE DISPARO! ⭐', Colors.amberAccent);
          } else if (item.type == 'burst') {
            _burstShotTicks = 200; // ~6 segundos
            _spawnFloatingText(_invadersShipX, _invadersShipY - 0.06, '¡DISPARO RÁPIDO! ⚡', Colors.cyanAccent);
          } else if (item.type == 'life') {
            _lives = (_lives + 1).clamp(0, 5);
            _spawnFloatingText(_invadersShipX, _invadersShipY - 0.06, '+1 VIDA 💖', Colors.redAccent);
          } else {
            _hasShield = true;
            _spawnFloatingText(_invadersShipX, _invadersShipY - 0.06, '¡ESCUDO ACTIVADO! 🧼', Colors.blueAccent);
          }
        }
      }

      // Mover enemigos y disparar ataques
      final rand = Random();

      for (int i = _invaderEnemies.length - 1; i >= 0; i--) {
        var enemy = _invaderEnemies[i];
        enemy.time += dt;

        if (enemy.visualType == 'alien' && enemy.type != 'boss') {
          enemy.x += enemy.vx * dt * 33.3 + sin(enemy.time * 5.0) * 0.005;
        } else {
          enemy.x += enemy.vx * dt * 33.3;
        }

        if (enemy.type == 'ufo') {
          if (enemy.x > 1.2) {
            _invaderEnemies.removeAt(i);
            continue;
          }
        } else if (enemy.x < 0.08 || enemy.x > 0.92) {
          enemy.vx = -enemy.vx;
          if (enemy.type != 'boss') {
            enemy.y += 0.04;
          }
          enemy.x = enemy.x.clamp(0.08, 0.92);
        }

        // Colisión física entre la nave y el enemigo
        double collisionRadius = enemy.type == 'boss' ? 0.14 : 0.08;
        bool hitX = (enemy.x - _invadersShipX).abs() < collisionRadius;
        bool hitY = (enemy.y - _invadersShipY).abs() < collisionRadius;

        if (hitX && hitY) {
          if (_hasShield) {
            _hasShield = false;
            _triggerFlash(Colors.blueAccent.withAlpha(90), 8);
            _triggerShake(4.0, 10);
            _spawnParticles(_invadersShipX, _invadersShipY, '🫧', 10);
            _spawnFloatingText(_invadersShipX, _invadersShipY - 0.05, '¡ESCUDO ROTO! 🫧', Colors.blueAccent);
            HapticFeedback.heavyImpact();
          } else {
            _lives--;
            _triggerFlash(Colors.red.withAlpha(120), 10);
            _triggerShake(8.0, 15);
            _spawnParticles(_invadersShipX, _invadersShipY, '💔', 12);
            _spawnFloatingText(_invadersShipX, _invadersShipY - 0.05, '💔 -1 Vida', Colors.redAccent);
            HapticFeedback.vibrate();
            if (_lives <= 0) {
              _isInvadersGameOver = true;
              _poopInvadersTimer?.cancel();
              return;
            }
          }

          if (enemy.type != 'boss') {
            _invaderEnemies.removeAt(i);
            _spawnParticles(enemy.x, enemy.y, '💥', 8);
            continue; // El enemigo normal se destruye al chocar
          } else {
            // El jefe retrocede un poco para no absorber todas las vidas del jugador instantáneamente
            enemy.y -= 0.15;
          }
        }

        // Lógica de ataques de los enemigos comunes
        if (enemy.type != 'boss') {
          double shootChance = 0.0008 + _invadersWave * 0.0002;
          if (rand.nextDouble() < shootChance) {
            _invaderLasers.add(InvaderLaser(x: enemy.x, y: enemy.y + 0.04, vy: 0.012, fromPlayer: false));
          }
          
          if (enemy.y >= 0.84) {
            _isInvadersGameOver = true;
            _poopInvadersTimer?.cancel();
            return;
          }
        }
      }

      // Comportamiento especial de Ataques del Boss
      if (_isBossActive && _invaderEnemies.isNotEmpty) {
        final boss = _invaderEnemies.firstWhere((e) => e.type == 'boss');
        _bossAttackTimer += dt;

        // Ataques del Boss según su tipo
        if (boss.bossType == 'fire') {
          // Boss Fuego: Lanza meteorito lento cada 2.5s
          if (_bossAttackTimer >= 2.5) {
            _bossAttackTimer = 0;
            _invaderLasers.add(InvaderLaser(
              x: _invadersShipX, // Apunta a la X actual del jugador
              y: boss.y + 0.08,
              vy: 0.007,
              fromPlayer: false,
              type: 'meteor',
            ));
            _spawnFloatingText(boss.x, boss.y + 0.08, '🔥 ¡METEORITO! 🔥', Colors.orangeAccent);
          }
        } else if (boss.bossType == 'electric') {
          // Boss Eléctrico: Lanza rayo zigzagueante cada 2.2s
          if (_bossAttackTimer >= 2.2) {
            _bossAttackTimer = 0;
            _invaderLasers.add(InvaderLaser(
              x: boss.x,
              y: boss.y + 0.08,
              vy: 0.014,
              fromPlayer: false,
              type: 'lightning',
            ));
            _spawnFloatingText(boss.x, boss.y + 0.08, '⚡ ¡RÁPIDO ZIGZAG! ⚡', Colors.cyanAccent);
          }
        } else if (boss.bossType == 'acid') {
          // Boss Ácido: Lanza burbuja ácida divisible cada 2.0s
          if (_bossAttackTimer >= 2.0) {
            _bossAttackTimer = 0;
            _invaderLasers.add(InvaderLaser(
              x: boss.x + (rand.nextDouble() - 0.5) * 0.2,
              y: boss.y + 0.08,
              vy: 0.010,
              fromPlayer: false,
              type: 'acid',
            ));
          }
        }

        // Ataque secundario del Boss (ráfaga normal de agua sucia)
        if (rand.nextDouble() < 0.04) {
          _invaderLasers.add(InvaderLaser(x: boss.x, y: boss.y + 0.07, vy: 0.013, fromPlayer: false));
        }
      }

      // Spawn OVNI dorado ocasional
      if (_ufoTimer > 25.0) {
        if (rand.nextDouble() < 0.4 && !_isBossActive) {
          _invaderEnemies.add(InvaderEnemy(
            x: -0.1,
            y: 0.06,
            vx: 0.016,
            hp: 3,
            type: 'ufo',
          ));
          _spawnFloatingText(0.5, 0.1, '🛸 ¡OVNI DEL BOTÍN!', Colors.yellowAccent);
        }
        _ufoTimer = 0.0;
      }

      // Comprobar si se eliminaron bacterias de la oleada normal (sólo si el Boss no está activo)
      if (_invaderEnemies.isEmpty && !_isBossActive) {
        widget.onAddKcoins(_invadersWave * 20);
        _invadersWave++;
        _spawnInvaderWave();
      }
    });
  }

  double _calculateDeltaTime() {
    final now = DateTime.now();
    final dt = now.difference(_lastTickTime).inMilliseconds / 1000.0;
    _lastTickTime = now;
    return dt.clamp(0.01, 0.1);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _gameWidth = constraints.maxWidth;
        _gameHeight = constraints.maxHeight;

        return Transform.translate(
          offset: Offset(_shakeX, _shakeY),
          child: GestureDetector(
            onPanUpdate: (details) {
              if (_isPausedLocalLocal || _isInvadersGameOver) return;
              setState(() {
                double speedMultiplier = widget.activeBuffCategory == AchievementCategory.stats ? 1.25 : 1.0;
                double deltaX = (details.delta.dx * speedMultiplier) / _gameWidth;
                _invadersShipX = (_invadersShipX + deltaX).clamp(0.08, 0.92);
                _invadersShipY = (_invadersShipY + (details.delta.dy * speedMultiplier) / _gameHeight).clamp(0.15, 0.92);
                _shipTilt = (_shipTilt + deltaX * 12.0).clamp(-0.5, 0.5);
              });
            },
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.greenAccent.withAlpha(40)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: PoopInvadersPainter(
                          shipX: _invadersShipX,
                          shipY: _invadersShipY,
                          shipTilt: _shipTilt,
                          lasers: _invaderLasers,
                          enemies: _invaderEnemies,
                          items: _invaderItems,
                          particles: _particles,
                          floatingTexts: _floatingTexts,
                          stars: _stars,
                          width: _gameWidth,
                          height: _gameHeight,
                          equippedSkin: widget.equippedSkin,
                          hasShield: _hasShield,
                          score: _score,
                          lives: _lives,
                          wave: _invadersWave,
                          gameTime: _gameTimeSeconds,
                        ),
                      ),
                    ),
                    if (_flashColor != null)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Container(color: _flashColor),
                        ),
                      ),
                    if (_isInvadersGameOver)
                      InGameOverlay(
                        showPause: false,
                        showGameOver: _isInvadersGameOver,
                        title: 'POOP INVADERS',
                        record: widget.highScore,
                        accentColor: Colors.greenAccent,
                        onRestart: _startPoopInvaders,
                        onExit: () => widget.onGameOver(_score),
                        onResume: () {},
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class PoopInvadersPainter extends CustomPainter {
  final double shipX;
  final double shipY;
  final double shipTilt;
  final List<InvaderLaser> lasers;
  final List<InvaderEnemy> enemies;
  final List<InvaderItem> items;
  final List<GameParticle> particles;
  final List<FloatingText> floatingTexts;
  final List<GameStar> stars;
  final double width;
  final double height;
  final String equippedSkin;
  final bool hasShield;
  final int score;
  final int lives;
  final int wave;
  final double gameTime;

  PoopInvadersPainter({
    required this.shipX,
    required this.shipY,
    required this.shipTilt,
    required this.lasers,
    required this.enemies,
    required this.items,
    required this.particles,
    required this.floatingTexts,
    required this.stars,
    required this.width,
    required this.height,
    required this.equippedSkin,
    required this.hasShield,
    required this.score,
    required this.lives,
    required this.wave,
    required this.gameTime,
  });

  void _drawToiletVector(Canvas canvas, Offset center, double size) {
    final double half = size / 2;
    
    // 1. Alas propulsoras laterales (Gris cromo oscuro)
    final wingPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(center.dx - half, center.dy),
        Offset(center.dx + half, center.dy),
        [const Color(0xFF334155), const Color(0xFF64748B), const Color(0xFF334155)],
        [0.0, 0.5, 1.0],
      );
    
    final wingPath = Path()
      ..moveTo(center.dx - half * 0.35, center.dy + half * 0.2)
      ..lineTo(center.dx - half * 1.3, center.dy + half * 0.75)
      ..lineTo(center.dx - half * 1.15, center.dy + half * 1.0)
      ..lineTo(center.dx - half * 0.25, center.dy + half * 0.85)
      ..moveTo(center.dx + half * 0.35, center.dy + half * 0.2)
      ..lineTo(center.dx + half * 1.3, center.dy + half * 0.75)
      ..lineTo(center.dx + half * 1.15, center.dy + half * 1.0)
      ..lineTo(center.dx + half * 0.25, center.dy + half * 0.85);
    canvas.drawPath(wingPath, wingPaint);

    // Contornos cian neón en las alas
    final neonPaint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawPath(wingPath, neonPaint);

    // Estelas de fuego de plasma cian
    final timeMs = DateTime.now().millisecondsSinceEpoch;
    final double fireHeight = half * 0.55 + sin(timeMs * 0.035) * 3.5;
    final flamePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, center.dy + half * 0.9),
        Offset(0, center.dy + half * 0.9 + fireHeight),
        [Colors.cyanAccent, Colors.blueAccent.withAlpha(0)],
      );
    canvas.drawRect(Rect.fromLTWH(center.dx - half * 1.18, center.dy + half * 0.9, 6, fireHeight), flamePaint);
    canvas.drawRect(Rect.fromLTWH(center.dx + half * 0.98, center.dy + half * 0.9, 6, fireHeight), flamePaint);

    // Cañones estilizados en las alas
    canvas.drawRect(Rect.fromLTWH(center.dx - half * 1.28, center.dy + half * 0.45, 5, 8), Paint()..color = const Color(0xFF1E293B));
    canvas.drawRect(Rect.fromLTWH(center.dx + half * 1.18, center.dy + half * 0.45, 5, 8), Paint()..color = const Color(0xFF1E293B));

    // 2. Tanque de agua trasero (Gris metálico con LEDs cian)
    final tankRect = Rect.fromLTWH(center.dx - half * 0.5, center.dy - half * 0.8, half * 1.0, half * 0.6);
    final tankPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(tankRect.left, tankRect.top),
        Offset(tankRect.right, tankRect.bottom),
        [const Color(0xFFE2E8F0), const Color(0xFF94A3B8)],
      );
    canvas.drawRRect(RRect.fromRectAndRadius(tankRect, const Radius.circular(5)), tankPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(tankRect, const Radius.circular(5)), Paint()..color = Colors.black.withAlpha(80)..style = PaintingStyle.stroke..strokeWidth = 1.0);
    
    // Luces de plasma en el depósito
    canvas.drawCircle(Offset(center.dx - 8, center.dy - half * 0.5), 2.0, Paint()..color = Colors.cyanAccent);
    canvas.drawCircle(Offset(center.dx + 8, center.dy - half * 0.5), 2.0, Paint()..color = Colors.cyanAccent);

    // 3. Taza central del inodoro (Porcelana blanca cromada)
    final bowlPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(center.dx - 6, center.dy + 2),
        half * 0.95,
        [Colors.white, const Color(0xFFE2E8F0), const Color(0xFFCBD5E1)],
        [0.0, 0.5, 1.0],
      );
    final Path bowlPath = Path()
      ..moveTo(center.dx - half * 0.65, center.dy - half * 0.1)
      ..quadraticBezierTo(center.dx - half * 0.55, center.dy + half * 0.55, center.dx - half * 0.2, center.dy + half * 0.75)
      ..lineTo(center.dx + half * 0.2, center.dy + half * 0.75)
      ..quadraticBezierTo(center.dx + half * 0.55, center.dy + half * 0.55, center.dx + half * 0.65, center.dy - half * 0.1)
      ..quadraticBezierTo(center.dx, center.dy + half * 0.12, center.dx - half * 0.65, center.dy - half * 0.1);
    canvas.drawPath(bowlPath, bowlPaint);
    canvas.drawPath(bowlPath, Paint()..color = const Color(0xFF475569)..style = PaintingStyle.stroke..strokeWidth = 1.0);

    // 4. Aro superior (Gris espacial cromado en vez de marrón)
    final rimRect = Rect.fromCenter(center: Offset(center.dx, center.dy - half * 0.1), width: half * 1.35, height: half * 0.45);
    final rimPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(rimRect.left, rimRect.top),
        Offset(rimRect.right, rimRect.bottom),
        [const Color(0xFF64748B), const Color(0xFF1E293B)],
      );
    canvas.drawOval(rimRect, rimPaint);
    canvas.drawOval(rimRect, Paint()..color = const Color(0xFF0F172A)..style = PaintingStyle.stroke..strokeWidth = 1.0);
    
    // Agua interior (Plasma de energía cian brillante)
    final innerRect = Rect.fromCenter(center: Offset(center.dx, center.dy - half * 0.1), width: half * 0.95, height: half * 0.28);
    final innerPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(center.dx, center.dy - half * 0.1),
        half * 0.5,
        [Colors.cyanAccent, const Color(0xFF0891B2)],
      );
    canvas.drawOval(innerRect, innerPaint);
  }

  void _drawBacteriaVector(Canvas canvas, Offset center, double size, {String type = 'normal', String bossType = 'none', String visualType = 'poop', int hp = 1, int maxHp = 1}) {
    final double half = size / 2;
    
    if (type == 'ufo') {
      final goldPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(center.dx - half, center.dy - half),
          Offset(center.dx + half, center.dy + half),
          [Colors.yellow, Colors.orangeAccent, Colors.yellowAccent],
          [0.0, 0.5, 1.0],
        );
      final ufoPath = Path()
        ..moveTo(center.dx - half * 1.5, center.dy)
        ..quadraticBezierTo(center.dx, center.dy - half, center.dx + half * 1.5, center.dy)
        ..quadraticBezierTo(center.dx, center.dy + half * 0.8, center.dx - half * 1.5, center.dy);
      canvas.drawPath(ufoPath, goldPaint);
      canvas.drawPath(ufoPath, Paint()..color = Colors.white24..style = PaintingStyle.stroke..strokeWidth = 2);
      canvas.drawCircle(Offset(center.dx, center.dy - half * 0.4), half * 0.6, Paint()..color = Colors.cyanAccent.withAlpha(150));
      return;
    }
    
    Color color1 = Colors.brown[400]!;
    Color color2 = Colors.brown[800]!;
    
    if (type == 'fast') {
      color1 = Colors.greenAccent[400]!;
      color2 = Colors.teal[900]!;
    } else if (type == 'boss') {
      if (bossType == 'fire') {
        color1 = Colors.orangeAccent[700]!;
        color2 = const Color(0xFF6F0000);
      } else if (bossType == 'electric') {
        color1 = Colors.cyanAccent[400]!;
        color2 = const Color(0xFF003050);
      } else if (bossType == 'acid') {
        color1 = Colors.greenAccent[400]!;
        color2 = const Color(0xFF004400);
      }
    }
    
    final timeMs = DateTime.now().millisecondsSinceEpoch;

    // Efectos de Aura del Boss (Fuego, Electricidad, Ácido)
    if (type == 'boss' && bossType == 'fire') {
      final double wave1 = sin(timeMs * 0.02) * 4.0;
      final double wave2 = cos(timeMs * 0.025) * 3.0;
      final flamePaint = Paint()
        ..shader = ui.Gradient.radial(
          center,
          half * 1.5,
          [Colors.yellow, Colors.orangeAccent, Colors.redAccent, Colors.transparent],
          [0.0, 0.33, 0.66, 1.0],
        );
      final flamePath = Path()
        ..moveTo(center.dx - half * 0.9, center.dy)
        ..quadraticBezierTo(center.dx - half * 1.2 + wave1, center.dy - half * 1.2 + wave2, center.dx, center.dy - half * 1.8)
        ..quadraticBezierTo(center.dx + half * 1.2 - wave2, center.dy - half * 1.2 + wave1, center.dx + half * 0.9, center.dy)
        ..close();
      canvas.drawPath(flamePath, flamePaint);
    }

    if (type == 'boss' && bossType == 'electric') {
      final sparkPaint = Paint()
        ..color = Colors.cyanAccent
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      final rand = Random(timeMs ~/ 80);
      for (int i = 0; i < 4; i++) {
        double angle = rand.nextDouble() * 2 * pi;
        double r1 = half * 0.9;
        double r2 = half * 1.5;
        double px1 = center.dx + cos(angle) * r1;
        double py1 = center.dy + sin(angle) * r1;
        double px2 = center.dx + cos(angle + 0.1) * r2;
        double py2 = center.dy + sin(angle + 0.1) * r2;
        canvas.drawLine(Offset(px1, py1), Offset(px2, py2), sparkPaint);
      }
    }

    if (type == 'boss' && bossType == 'acid') {
      final bubblePaint = Paint()..color = Colors.greenAccent[400]!.withAlpha(160);
      final rand = Random(42);
      for (int i = 0; i < 4; i++) {
        double offsetTime = (timeMs * 0.03 * (0.8 + rand.nextDouble()) + i * 20) % (half * 1.5);
        double bx = center.dx + (rand.nextDouble() - 0.5) * half * 1.2;
        double by = center.dy + half * 0.4 + offsetTime;
        canvas.drawCircle(Offset(bx, by), 3, bubblePaint);
      }
    }

    // Dibujar según el visualType (para enemigos comunes) o como Caca base para el Boss
    if (type == 'boss' || visualType == 'poop') {
      // 1. CACA ALIENÍGENA CLÁSICA (Marrón/Boss - Trazado de elipses perfectas concéntricas para alta definición)
      final poopPaint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(center.dx - half * 0.15, center.dy - half * 0.2),
          half * 1.1,
          [color1, color2],
        );

      final strokePaint = Paint()
        ..color = const Color(0xFF3B2314)
        ..style = PaintingStyle.stroke
        ..strokeWidth = type == 'boss' ? 2.5 : 1.2;

      // Nivel inferior (Base)
      final baseRect = Rect.fromCenter(center: Offset(center.dx, center.dy + half * 0.4), width: half * 1.7, height: half * 0.55);
      canvas.drawOval(baseRect, poopPaint);
      canvas.drawOval(baseRect, strokePaint);

      // Nivel medio
      final midRect = Rect.fromCenter(center: Offset(center.dx, center.dy + half * 0.02), width: half * 1.3, height: half * 0.48);
      canvas.drawOval(midRect, poopPaint);
      canvas.drawOval(midRect, strokePaint);

      // Nivel superior (Punta)
      final topRect = Rect.fromCenter(center: Offset(center.dx, center.dy - half * 0.32), width: half * 0.85, height: half * 0.42);
      canvas.drawOval(topRect, poopPaint);
      canvas.drawOval(topRect, strokePaint);

      // Antena marciana
      final double antAngle = sin(timeMs * 0.02) * 0.12;
      canvas.save();
      canvas.translate(center.dx, center.dy - half * 0.5);
      canvas.rotate(antAngle);
      canvas.drawLine(Offset.zero, const Offset(0, -9), Paint()..color = Colors.grey[400]!..strokeWidth = 1.5);
      final antennaColor = Color.lerp(Colors.greenAccent, Colors.yellowAccent, (sin(timeMs * 0.035) + 1.0) / 2.0)!;
      canvas.drawCircle(const Offset(0, -10), 3.0, Paint()..color = antennaColor);
      canvas.restore();

      // Ojos
      final eyePaint = Paint()..color = type == 'boss' ? Colors.yellowAccent : Colors.redAccent;
      final pupilPaint = Paint()..color = type == 'boss' ? Colors.red : Colors.white;

      if (type == 'boss') {
        canvas.drawCircle(Offset(center.dx - 12, center.dy - 2), 7, eyePaint);
        canvas.drawCircle(Offset(center.dx - 12, center.dy - 2), 2, pupilPaint);
        
        canvas.drawCircle(Offset(center.dx + 12, center.dy - 2), 7, eyePaint);
        canvas.drawCircle(Offset(center.dx + 12, center.dy - 2), 2, pupilPaint);

        canvas.drawCircle(Offset(center.dx, center.dy - 10), 8, eyePaint);
        canvas.drawCircle(Offset(center.dx, center.dy - 10), 3, pupilPaint);
      } else {
        canvas.drawCircle(Offset(center.dx - half * 0.3, center.dy + 2), 3.5, eyePaint);
        canvas.drawCircle(Offset(center.dx - half * 0.3, center.dy + 2), 1.0, pupilPaint);
        
        canvas.drawCircle(Offset(center.dx + half * 0.3, center.dy + 2), 3.5, eyePaint);
        canvas.drawCircle(Offset(center.dx + half * 0.3, center.dy + 2), 1.0, pupilPaint);
      }
    } else if (visualType == 'bacteria') {
      // 2. BACTERIA ESPACIAL (Morada neón, cilios de bolitas y núcleo 3D)
      final bacColor1 = Colors.purpleAccent;
      final bacColor2 = Colors.purple[900]!;
      
      // Dibujar cilios circulares perfectos a su alrededor
      final cilioPaint = Paint()..color = Colors.purpleAccent.withAlpha(200);
      final int cilioCount = 10;
      for (int i = 0; i < cilioCount; i++) {
        double angle = (i * 2 * pi / cilioCount) + sin(timeMs * 0.02 + i) * 0.15;
        double radiusOffset = half * 1.12 + sin(timeMs * 0.03 + i) * 1.5;
        double cx = center.dx + cos(angle) * radiusOffset;
        double cy = center.dy + sin(angle) * radiusOffset;
        canvas.drawCircle(Offset(cx, cy), 3, cilioPaint);
      }

      final bodyPaint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(center.dx - 2, center.dy - 2),
          half * 0.95,
          [bacColor1, bacColor2],
        );
      
      // Dibujar cuerpo circular de la bacteria
      canvas.drawCircle(center, half * 0.95, bodyPaint);
      canvas.drawCircle(center, half * 0.95, Paint()..color = Colors.purple[800]!..style = PaintingStyle.stroke..strokeWidth = 1.2);

      // Núcleo celular neón
      canvas.drawCircle(center, half * 0.35, Paint()..color = Colors.cyanAccent.withAlpha(180));
      canvas.drawCircle(center, half * 0.15, Paint()..color = Colors.white);

      // Ojos de bacteria enojada
      final eyePaint = Paint()..color = Colors.redAccent;
      canvas.drawCircle(Offset(center.dx - half * 0.35, center.dy - half * 0.2), 3, eyePaint);
      canvas.drawCircle(Offset(center.dx + half * 0.35, center.dy - half * 0.2), 3, eyePaint);
    } else if (visualType == 'alien') {
      // 3. ALIENÍGENA CLÁSICO (Verde fosforito o Naranja si está dañado)
      final aliColor1 = (hp < maxHp) ? Colors.orangeAccent : Colors.greenAccent[400]!;
      final aliColor2 = (hp < maxHp) ? Colors.red[900]! : Colors.green[900]!;

      final headPaint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(center.dx - 2, center.dy - 3),
          half * 1.05,
          [aliColor1, aliColor2],
        );

      final Path alienPath = Path()
        ..moveTo(center.dx - half * 0.75, center.dy - half * 0.3)
        ..cubicTo(
          center.dx - half * 0.85, center.dy - half * 0.95,
          center.dx + half * 0.85, center.dy - half * 0.95,
          center.dx + half * 0.75, center.dy - half * 0.3,
        )
        ..cubicTo(
          center.dx + half * 0.65, center.dy + half * 0.35,
          center.dx + half * 0.3, center.dy + half * 0.75,
          center.dx, center.dy + half * 0.75,
        )
        ..cubicTo(
          center.dx - half * 0.3, center.dy + half * 0.75,
          center.dx - half * 0.65, center.dy + half * 0.35,
          center.dx - half * 0.75, center.dy - half * 0.3,
        )
        ..close();
      
      canvas.drawPath(alienPath, headPaint);
      canvas.drawPath(alienPath, Paint()..color = const Color(0xFF0F172A)..style = PaintingStyle.stroke..strokeWidth = 1.2);

      // Ojos negros ovalados inclinados gigantes con brillo
      final eyePaint = Paint()..color = const Color(0xFF020617);
      
      // Ojo izquierdo
      canvas.save();
      canvas.translate(center.dx - half * 0.3, center.dy - half * 0.05);
      canvas.rotate(0.22);
      final leftEyeRect = Rect.fromCenter(center: Offset.zero, width: half * 0.45, height: half * 0.75);
      canvas.drawOval(leftEyeRect, eyePaint);
      canvas.drawCircle(const Offset(-1.5, -2), 1.5, Paint()..color = Colors.white);
      canvas.restore();

      // Ojo derecho
      canvas.save();
      canvas.translate(center.dx + half * 0.3, center.dy - half * 0.05);
      canvas.rotate(-0.22);
      final rightEyeRect = Rect.fromCenter(center: Offset.zero, width: half * 0.45, height: half * 0.75);
      canvas.drawOval(rightEyeRect, eyePaint);
      canvas.drawCircle(const Offset(1.5, -2), 1.5, Paint()..color = Colors.white);
      canvas.restore();

      // Antena Roswell
      canvas.drawLine(
        Offset(center.dx, center.dy - half * 0.8),
        Offset(center.dx, center.dy - half * 1.15),
        Paint()..color = Colors.grey[400]!..strokeWidth = 1.2,
      );
      canvas.drawCircle(Offset(center.dx, center.dy - half * 1.2), 2.5, Paint()..color = Colors.greenAccent);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Dibujar espacio profundo con nebulosas y estrellas
    final bgPaint = Paint()..color = const Color(0xFF030712);
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), bgPaint);

    for (var star in stars) {
      final starPaint = Paint()..color = Colors.white.withAlpha((150 * (star.size/2.5)).clamp(40, 255).toInt());
      canvas.drawCircle(Offset(star.x * width, star.y * height), star.size, starPaint);
    }

    // Grid neón de fondo
    final gridPaint = Paint()
      ..color = Colors.greenAccent.withAlpha(8)
      ..strokeWidth = 0.5;
    for (double i = 0; i < width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, height), gridPaint);
    }
    for (double j = 0; j < height; j += 40) {
      canvas.drawLine(Offset(0, j), Offset(width, j), gridPaint);
    }

    // 2. Dibujar láseres/proyectiles
    for (var laser in lasers) {
      final lCenter = Offset(laser.x * width, laser.y * height);
      Color laserColor = laser.fromPlayer ? Colors.cyanAccent : Colors.purpleAccent;
      double lWidth = 6.0;
      double lHeight = 16.0;

      if (!laser.fromPlayer) {
        if (laser.type == 'meteor') {
          laserColor = Colors.orangeAccent;
          lWidth = 24.0;
          lHeight = 24.0;
        } else if (laser.type == 'lightning') {
          laserColor = Colors.cyanAccent;
          lWidth = 7.0;
          lHeight = 20.0;
        } else if (laser.type == 'acid' || laser.type == 'acid_sub') {
          laserColor = Colors.greenAccent[400]!;
          lWidth = 10.0;
          lHeight = 10.0;
        }
      }

      final glowPaint = Paint()
        ..color = laserColor.withAlpha(100)
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);

      if (laser.type == 'meteor') {
        canvas.drawCircle(lCenter, lWidth / 2 + 3, glowPaint);
        canvas.drawCircle(lCenter, lWidth / 2, Paint()..shader = ui.Gradient.radial(lCenter, lWidth / 2, [Colors.yellow, Colors.orangeAccent[700]!]));
      } else if (laser.type == 'acid' || laser.type == 'acid_sub') {
        canvas.drawCircle(lCenter, lWidth / 2 + 2, glowPaint);
        canvas.drawCircle(lCenter, lWidth / 2, Paint()..color = Colors.greenAccent[400]!);
      } else {
        // Trail para láseres normales
        final trailPaint = Paint()
          ..shader = ui.Gradient.linear(
            Offset(lCenter.dx, lCenter.dy - lHeight / 2),
            Offset(lCenter.dx, lCenter.dy + lHeight * 2.0 * (laser.fromPlayer ? 1 : -1)),
            [laserColor.withAlpha(180), laserColor.withAlpha(0)],
          );
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(lCenter.dx, lCenter.dy + lHeight * 0.8 * (laser.fromPlayer ? 1 : -1)),
            width: lWidth * 0.6,
            height: lHeight * 2.0,
          ),
          trailPaint,
        );

        canvas.drawOval(Rect.fromCenter(center: lCenter, width: lWidth, height: lHeight), glowPaint);
        canvas.drawOval(Rect.fromCenter(center: lCenter, width: lWidth / 2, height: lHeight * 0.75), Paint()..color = Colors.white);
      }
    }

    // 3. Dibujar enemigos
    for (var enemy in enemies) {
      final eCenter = Offset(enemy.x * width, enemy.y * height);
      double size = enemy.type == 'boss' ? 54.0 : (enemy.type == 'ufo' ? 40.0 : 22.0);
      _drawBacteriaVector(canvas, eCenter, size, type: enemy.type, bossType: enemy.bossType, visualType: enemy.visualType, hp: enemy.hp, maxHp: enemy.maxHp);

      // Si es Jefe, dibujar su barra de vida encima
      if (enemy.type == 'boss') {
        final barRect = Rect.fromCenter(center: Offset(eCenter.dx, eCenter.dy - 44), width: 60, height: 6);
        canvas.drawRRect(RRect.fromRectAndRadius(barRect, const Radius.circular(3)), Paint()..color = Colors.black54);
        
        double lifePct = (enemy.hp / enemy.maxHp).clamp(0.0, 1.0);
        final lifeRect = Rect.fromLTWH(barRect.left, barRect.top, 60 * lifePct, 6);
        
        Color hpColor = Colors.redAccent;
        if (enemy.bossType == 'electric') hpColor = Colors.cyanAccent;
        if (enemy.bossType == 'acid') hpColor = Colors.greenAccent[400]!;

        canvas.drawRRect(RRect.fromRectAndRadius(lifeRect, const Radius.circular(3)), Paint()..color = hpColor);
      }
    }

    // 4. Dibujar items (Powerups caídos)
    for (var item in items) {
      final iCenter = Offset(item.x * width, item.y * height);
      Color itemColor = Colors.amber;
      String emoji = '⭐';
      if (item.type == 'burst') {
        itemColor = Colors.cyan;
        emoji = '⚡';
      } else if (item.type == 'shield') {
        itemColor = Colors.blue;
        emoji = '🧼';
      } else if (item.type == 'life') {
        itemColor = Colors.redAccent;
        emoji = '💖';
      }

      final glow = Paint()
        ..color = itemColor.withAlpha(90)
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 6);
      canvas.drawCircle(iCenter, 14, glow);

      final ft = TextPainter(
        text: TextSpan(text: emoji, style: const TextStyle(fontSize: 16)),
        textDirection: TextDirection.ltr,
      );
      ft.layout();
      ft.paint(canvas, Offset(iCenter.dx - ft.width / 2, iCenter.dy - ft.height / 2));
    }

    // 5. Dibujar jugador (Inodoro + Skin Caca)
    final sCenter = Offset(shipX * width, shipY * height);
    if (hasShield) {
      final shieldPaint = Paint()
        ..color = Colors.blueAccent.withAlpha(60)
        ..style = PaintingStyle.fill;
      final borderPaint = Paint()
        ..color = Colors.blueAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(sCenter, 44, shieldPaint);
      canvas.drawCircle(sCenter, 44, borderPaint);
    }

    // Dibujar inodoro con rotación relativa
    canvas.save();
    canvas.translate(sCenter.dx, sCenter.dy);
    canvas.rotate(shipTilt);
    canvas.translate(-sCenter.dx, -sCenter.dy);

    _drawToiletVector(canvas, sCenter, 60);

    // Dibujar la caca equipada asomando por la taza
    PoopSkinDrawer.drawPoop(canvas, Offset(sCenter.dx, sCenter.dy - 11), 32, skin: equippedSkin);
    
    canvas.restore();

    // 6. Dibujar partículas
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

    // 7. Dibujar textos flotantes
    for (var ft in floatingTexts) {
      canvas.save();
      final ftPainter = TextPainter(
        text: TextSpan(
          text: ft.text,
          style: TextStyle(
            color: ft.color.withAlpha((ft.opacity * 255).toInt()),
            fontSize: ft.fontSize,
            fontWeight: FontWeight.bold,
            shadows: const [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1))],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      ftPainter.layout();
      ftPainter.paint(canvas, Offset(ft.x - ftPainter.width / 2, ft.y - ftPainter.height / 2));
      canvas.restore();
    }

    // 8. Dibujar UI superior (Puntos, Vidas, Tiempo, Oleada)
    final textStyle = const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5);
    
    // Puntos
    final scorePainter = TextPainter(
      text: TextSpan(text: 'SCORE: $score', style: textStyle),
      textDirection: TextDirection.ltr,
    );
    scorePainter.layout();
    scorePainter.paint(canvas, const Offset(12, 12));

    // Tiempo transcurrido
    final timePainter = TextPainter(
      text: TextSpan(text: 'TIEMPO: ${gameTime.toInt()}s', style: TextStyle(color: Colors.amber[700], fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      textDirection: TextDirection.ltr,
    );
    timePainter.layout();
    timePainter.paint(canvas, const Offset(12, 28));

    // Oleada
    final wavePainter = TextPainter(
      text: TextSpan(text: 'OLEADA: $wave', style: TextStyle(color: Colors.greenAccent[400], fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      textDirection: TextDirection.ltr,
    );
    wavePainter.layout();
    wavePainter.paint(canvas, Offset(width / 2 - wavePainter.width / 2, 12));

    // Vidas
    String livesStr = '❤️' * lives;
    final livesPainter = TextPainter(
      text: TextSpan(text: livesStr, style: const TextStyle(fontSize: 11)),
      textDirection: TextDirection.ltr,
    );
    livesPainter.layout();
    livesPainter.paint(canvas, Offset(width - livesPainter.width - 12, 12));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
