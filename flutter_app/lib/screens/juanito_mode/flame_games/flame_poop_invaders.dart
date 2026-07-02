import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame_audio/flame_audio.dart';
import '../shared_game_components.dart' show PoopSkinDrawer, GameAudio;
import '../../../models/achievement.dart';
import 'sprite_rasterizer.dart';

class PoopInvadersFlameGame extends FlameGame with PanDetector, HasCollisionDetection {
  final String equippedSkin;
  final bool hasInitialTripleShot;
  final bool hasInitialBurstShot;
  final AchievementCategory? activeBuffCategory;

  final Function(int) onGameOver;
  final Function(int) onAddKcoins;
  final Function(int) onScoreChanged;
  final Function(int) onLivesChanged;
  final Function(int) onWaveChanged;
  final Function(double) onTimeChanged;

  // Object Pools para rendimiento extremo
  final List<LaserComponent> inactiveLasers = [];
  final List<GameParticleComponent> inactiveParticles = [];

  late PlayerShip player;
  late DeepSpaceBackground sky;
  
  int score = 0;
  int lives = 5;
  int wave = 1;
  double gameTimeSeconds = 0.0;
  
  // Boss state
  bool isBossActive = false;
  int nextBossIndex = 1;
  final List<int> bossSpawnTimes = [30, 75, 135, 210, 295, 390, 495, 610];
  double ufoTimer = 0.0;

  // Screen shake state
  double shakeTimer = 0.0;
  double shakeIntensity = 0.0;

  PoopInvadersFlameGame({
    required this.equippedSkin,
    required this.hasInitialTripleShot,
    required this.hasInitialBurstShot,
    required this.activeBuffCategory,
    required this.onGameOver,
    required this.onAddKcoins,
    required this.onScoreChanged,
    required this.onLivesChanged,
    required this.onWaveChanged,
    required this.onTimeChanged,
  });

  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    await FlameAudio.audioCache.loadAll([
      'shoot.wav',
      'explosion.wav',
      'hit.wav',
    ]);
    
    if (activeBuffCategory == AchievementCategory.games) lives++;

    // Background
    sky = DeepSpaceBackground();
    add(sky);

    // Player
    player = PlayerShip(
      skin: equippedSkin,
      startTriple: hasInitialTripleShot,
      startBurst: hasInitialBurstShot,
    );
    player.position = Vector2(size.x / 2, size.y * 0.86);
    add(player);

    _spawnWave();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (paused) return;

    gameTimeSeconds += dt;
    ufoTimer += dt;
    onTimeChanged(gameTimeSeconds);

    if (shakeTimer > 0) {
      shakeTimer -= dt;
      if (shakeTimer <= 0) shakeIntensity = 0.0;
    }

    // Boss spawning logic
    if (nextBossIndex - 1 < bossSpawnTimes.length &&
        gameTimeSeconds >= bossSpawnTimes[nextBossIndex - 1] &&
        !isBossActive) {
      _spawnBoss(nextBossIndex);
      nextBossIndex++;
    }

    // Normal wave progression (only if no boss is active)
    if (!isBossActive) {
      bool hasEnemies = children.whereType<InvaderEnemy>().isNotEmpty;
      if (!hasEnemies) {
        onAddKcoins(wave * 20);
        wave++;
        onWaveChanged(wave);
        _spawnWave();
      }
    }

    // Golden UFO Spawner
    if (ufoTimer > 25.0) {
      if (Random().nextDouble() < 0.4 && !isBossActive) {
        add(InvaderEnemy(type: 'ufo', maxHp: 3, bossType: 'none', visualType: 'ufo')
          ..position = Vector2(-20, size.y * 0.06)
          ..velocity = Vector2(100.0, 0));
        addFloatingText('🛸 ¡OVNI DEL BOTÍN!', Vector2(size.x / 2, size.y * 0.1), Colors.yellowAccent);
      }
      ufoTimer = 0.0;
    }
  }

  void _spawnWave() {
    addFloatingText('¡OLEADA $wave! 👾', Vector2(size.x / 2, size.y * 0.45), Colors.greenAccent, size: 24);

    int cols = 5;
    int rows = 2;
    double speedX = 60.0 + wave * 10.0;
    bool isAlienWave = nextBossIndex > 1;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        String type = (r == 0 && wave > 1) ? 'fast' : 'normal';
        add(InvaderEnemy(
          type: type,
          maxHp: isAlienWave ? 2 : 1,
          bossType: 'none',
          visualType: isAlienWave ? 'alien' : 'bacteria',
        )
          ..position = Vector2(size.x * 0.16 + c * (size.x * 0.17), size.y * 0.12 + r * (size.y * 0.12))
          ..velocity = Vector2(c % 2 == 0 ? speedX : -speedX, 0));
      }
    }
  }

  void _spawnBoss(int bossNumber) {
    addFloatingText('⚠️ ¡ALERTA DE JEFE FINAL! ⚠️', Vector2(size.x / 2, size.y * 0.45), Colors.redAccent, size: 24);
    
    // Clear normal enemies
    for (var enemy in children.whereType<InvaderEnemy>()) {
      enemy.die(silent: true);
    }

    isBossActive = true;

    String bType = 'fire';
    int maxHp = 30 + bossNumber * 10;
    if (activeBuffCategory == AchievementCategory.social) {
      maxHp = (maxHp * 0.85).toInt();
    }

    if (bossNumber == 2) bType = 'electric';
    else if (bossNumber == 3) bType = 'acid';
    else {
      final types = ['fire', 'electric', 'acid'];
      bType = types[(bossNumber - 1) % 3];
    }

    add(InvaderEnemy(
      type: 'boss',
      maxHp: maxHp,
      bossType: bType,
      visualType: 'poop', // Bosses use the big alien poop drawing
    )
      ..position = Vector2(size.x / 2, size.y * 0.18)
      ..velocity = Vector2(80.0, 0));
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    if (paused) return;
    
    double speedMultiplier = activeBuffCategory == AchievementCategory.stats ? 1.25 : 1.0;
    double deltaX = info.delta.global.x * speedMultiplier;
    double deltaY = info.delta.global.y * speedMultiplier;

    player.position.x = (player.position.x + deltaX).clamp(size.x * 0.08, size.x * 0.92);
    player.position.y = (player.position.y + deltaY).clamp(size.y * 0.15, size.y * 0.92);

    // Añadida inercia premium aerodinámica basada en el movimiento horizontal
    player.tiltAngle = (player.tiltAngle + deltaX * 0.015).clamp(-0.5, 0.5);
  }

  void hitPlayer() {
    if (player.hasShield) {
      player.hasShield = false;
      addFloatingText('¡ESCUDO ROTO! 🫧', player.position.clone()..y -= 30, Colors.blueAccent);
      HapticFeedback.heavyImpact();
      shakeScreen(duration: 0.25, intensity: 8.0);
    } else {
      lives--;
      onLivesChanged(lives);
      addFloatingText('💔 -1 Vida', player.position.clone()..y -= 30, Colors.redAccent);
      HapticFeedback.vibrate();
      shakeScreen(duration: 0.35, intensity: 12.0);
      
      if (lives <= 0) {
        triggerGameOver();
      }
    }
  }

  void addScore(int points) {
    score += points;
    onScoreChanged(score);
  }

  void triggerGameOver() {
    pauseEngine();
    onGameOver(score);
  }

  void addFloatingText(String text, Vector2 pos, Color color, {double size = 14.0}) {
    add(FloatingTextComponent(text: text, color: color, fontSize: size)..position = pos);
  }

  void spawnLaser({required Vector2 pos, required double vy, double vx = 0, required bool fromPlayer, String type = 'normal'}) {
    add(LaserComponent(vy: vy, vx: vx, fromPlayer: fromPlayer, type: type)..position = pos.clone());
  }

  void spawnParticles(Vector2 pos, String emoji, int count, {double speed = 1.0}) {
    for (int i = 0; i < count; i++) {
      add(GameParticleComponent(emoji: emoji, speedMod: speed)..position = pos.clone());
    }
  }

  void shakeScreen({double duration = 0.2, double intensity = 6.0}) {
    shakeTimer = duration;
    shakeIntensity = intensity;
  }

  @override
  void render(Canvas canvas) {
    if (shakeTimer > 0) {
      final rand = Random();
      final dx = (rand.nextDouble() - 0.5) * 2 * shakeIntensity;
      final dy = (rand.nextDouble() - 0.5) * 2 * shakeIntensity;
      canvas.save();
      canvas.translate(dx, dy);
      super.render(canvas);
      canvas.restore();
    } else {
      super.render(canvas);
    }
  }
}

// --- COMPONENTS ---

class DeepSpaceBackground extends PositionComponent with HasGameReference<PoopInvadersFlameGame> {
  final List<GameStar> _stars = [];

  @override
  void onMount() {
    super.onMount();
    final rand = Random();
    for (int i = 0; i < 40; i++) {
      _stars.add(GameStar(
        x: rand.nextDouble() * game.size.x,
        y: rand.nextDouble() * game.size.y,
        speed: 20.0 + rand.nextDouble() * 80.0,
        size: 0.5 + rand.nextDouble() * 2.0,
      ));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    for (var star in _stars) {
      star.y += star.speed * dt;
      if (star.y > game.size.y) {
        star.y = 0;
        star.x = Random().nextDouble() * game.size.x;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final bgPaint = Paint()..color = const Color(0xFF030712);
    canvas.drawRect(Rect.fromLTWH(0, 0, game.size.x, game.size.y), bgPaint);

    for (var star in _stars) {
      final starPaint = Paint()..color = Colors.white.withAlpha((150 * (star.size / 2.5)).clamp(40, 255).toInt());
      canvas.drawCircle(Offset(star.x, star.y), star.size, starPaint);
    }

    // Neon grid
    final gridPaint = Paint()..color = Colors.greenAccent.withAlpha(8)..strokeWidth = 0.5;
    for (double i = 0; i < game.size.x; i += 40) canvas.drawLine(Offset(i, 0), Offset(i, game.size.y), gridPaint);
    for (double j = 0; j < game.size.y; j += 40) canvas.drawLine(Offset(0, j), Offset(game.size.x, j), gridPaint);
  }
}

class GameStar {
  double x, y, speed, size;
  GameStar({required this.x, required this.y, required this.speed, required this.size});
}

class PlayerShip extends PositionComponent with HasGameReference<PoopInvadersFlameGame>, CollisionCallbacks {
  final String skin;
  double tiltAngle = 0;
  double fireCooldown = 0;
  
  double tripleShotTime = 0;
  double burstShotTime = 0;
  bool hasShield = false;

  ui.Image? cachedShipImage;

  PlayerShip({required this.skin, bool startTriple = false, bool startBurst = false}) {
    size = Vector2(60, 60);
    anchor = Anchor.center;
    add(CircleHitbox(radius: 20));

    if (startTriple) tripleShotTime = 6.0;
    if (startBurst) burstShotTime = 6.0;
  }

  @override
  Future<void> onLoad() async {
    cachedShipImage = await SpriteRasterizer.rasterize(100, 100, (canvas) {
      final center = const Offset(50, 50);
      _drawToiletVectorStatic(canvas, center, 60);
      PoopSkinDrawer.drawPoop(canvas, Offset(center.dx, center.dy - 11), 32, skin: skin);
    });
  }

  @override
  void update(double dt) {
    super.update(dt);

    tiltAngle *= 0.88; // Decaimiento suave de la inercia

    if (tripleShotTime > 0) tripleShotTime -= dt;
    if (burstShotTime > 0) burstShotTime -= dt;

    if (fireCooldown > 0) {
      fireCooldown -= dt;
    } else {
      fireCooldown = burstShotTime > 0 ? 0.15 : 0.36;
      _fireLaser();
    }

    if (Random().nextDouble() < 0.22) {
      game.spawnParticles(position.clone() + Vector2(0, 20), '🧼', 1, speed: 0.5);
    }
  }

  void _fireLaser() {
    HapticFeedback.selectionClick();
    double lSpeed = -400.0;
    
    if (tripleShotTime > 0) {
      game.spawnLaser(pos: position.clone() + Vector2(0, -25), vy: lSpeed, vx: 0, fromPlayer: true);
      game.spawnLaser(pos: position.clone() + Vector2(-15, -20), vy: lSpeed, vx: -80, fromPlayer: true);
      game.spawnLaser(pos: position.clone() + Vector2(15, -20), vy: lSpeed, vx: 80, fromPlayer: true);
    } else {
      game.spawnLaser(pos: position.clone() + Vector2(0, -25), vy: lSpeed, vx: 0, fromPlayer: true);
    }
    GameAudio.play('shoot.wav', volume: 0.06);
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);

    if (hasShield) {
      final shieldPaint = Paint()..color = Colors.blueAccent.withAlpha(60)..style = PaintingStyle.fill;
      final borderPaint = Paint()..color = Colors.blueAccent..style = PaintingStyle.stroke..strokeWidth = 2.0;
      canvas.drawCircle(center, 44, shieldPaint);
      canvas.drawCircle(center, 44, borderPaint);
    }

    if (tripleShotTime > 0) {
      final progressPaint = Paint()
        ..color = Colors.amberAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      final rect = Rect.fromCircle(center: center, radius: 36);
      double sweepAngle = (tripleShotTime / 6.0) * 2 * pi;
      canvas.drawArc(rect, -pi / 2, sweepAngle, false, progressPaint);
    }
    if (burstShotTime > 0) {
      final progressPaint = Paint()
        ..color = Colors.cyanAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      final rect = Rect.fromCircle(center: center, radius: 32);
      double sweepAngle = (burstShotTime / 6.0) * 2 * pi;
      canvas.drawArc(rect, -pi / 2, sweepAngle, false, progressPaint);
    }

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(tiltAngle);
    canvas.translate(-center.dx, -center.dy);

    // Dibujar propulsores animados (fuego) debajo de la nave
    _drawAnimatedFlames(canvas, center, 60);

    if (cachedShipImage != null) {
      canvas.drawImage(cachedShipImage!, Offset(center.dx - 50, center.dy - 50), Paint());
    }

    canvas.restore();
  }

  void _drawAnimatedFlames(Canvas canvas, Offset center, double size) {
    final double half = size / 2;
    final timeMs = DateTime.now().millisecondsSinceEpoch;
    final double fireHeight = half * 0.55 + sin(timeMs * 0.035) * 3.5;
    final flamePaint = Paint()..shader = ui.Gradient.linear(Offset(0, center.dy + half * 0.9), Offset(0, center.dy + half * 0.9 + fireHeight), [Colors.cyanAccent, Colors.blueAccent.withAlpha(0)]);
    canvas.drawRect(Rect.fromLTWH(center.dx - half * 1.18, center.dy + half * 0.9, 6, fireHeight), flamePaint);
    canvas.drawRect(Rect.fromLTWH(center.dx + half * 0.98, center.dy + half * 0.9, 6, fireHeight), flamePaint);
  }

  void _drawToiletVectorStatic(Canvas canvas, Offset center, double size) {
    final double half = size / 2;
    // Alas propulsoras laterales
    final wingPaint = Paint()
      ..shader = ui.Gradient.linear(Offset(center.dx - half, center.dy), Offset(center.dx + half, center.dy), [const Color(0xFF334155), const Color(0xFF64748B), const Color(0xFF334155)], [0.0, 0.5, 1.0]);
    final wingPath = Path()
      ..moveTo(center.dx - half * 0.35, center.dy + half * 0.2)..lineTo(center.dx - half * 1.3, center.dy + half * 0.75)..lineTo(center.dx - half * 1.15, center.dy + half * 1.0)..lineTo(center.dx - half * 0.25, center.dy + half * 0.85)
      ..moveTo(center.dx + half * 0.35, center.dy + half * 0.2)..lineTo(center.dx + half * 1.3, center.dy + half * 0.75)..lineTo(center.dx + half * 1.15, center.dy + half * 1.0)..lineTo(center.dx + half * 0.25, center.dy + half * 0.85);
    canvas.drawPath(wingPath, wingPaint);
    canvas.drawPath(wingPath, Paint()..color = Colors.cyanAccent..style = PaintingStyle.stroke..strokeWidth = 1.6);

    // Tanque
    final tankRect = Rect.fromLTWH(center.dx - half * 0.5, center.dy - half * 0.8, half * 1.0, half * 0.6);
    final tankPaint = Paint()..shader = ui.Gradient.linear(Offset(tankRect.left, tankRect.top), Offset(tankRect.right, tankRect.bottom), [const Color(0xFFE2E8F0), const Color(0xFF94A3B8)]);
    canvas.drawRRect(RRect.fromRectAndRadius(tankRect, const Radius.circular(5)), tankPaint);

    // Taza
    final bowlPaint = Paint()..shader = ui.Gradient.radial(Offset(center.dx - 6, center.dy + 2), half * 0.95, [Colors.white, const Color(0xFFE2E8F0), const Color(0xFFCBD5E1)], [0.0, 0.5, 1.0]);
    final Path bowlPath = Path()
      ..moveTo(center.dx - half * 0.65, center.dy - half * 0.1)..quadraticBezierTo(center.dx - half * 0.55, center.dy + half * 0.55, center.dx - half * 0.2, center.dy + half * 0.75)
      ..lineTo(center.dx + half * 0.2, center.dy + half * 0.75)..quadraticBezierTo(center.dx + half * 0.55, center.dy + half * 0.55, center.dx + half * 0.65, center.dy - half * 0.1)
      ..quadraticBezierTo(center.dx, center.dy + half * 0.12, center.dx - half * 0.65, center.dy - half * 0.1);
    canvas.drawPath(bowlPath, bowlPaint);

    // Aro
    final rimRect = Rect.fromCenter(center: Offset(center.dx, center.dy - half * 0.1), width: half * 1.35, height: half * 0.45);
    final rimPaint = Paint()..shader = ui.Gradient.linear(Offset(rimRect.left, rimRect.top), Offset(rimRect.right, rimRect.bottom), [const Color(0xFF64748B), const Color(0xFF1E293B)]);
    canvas.drawOval(rimRect, rimPaint);
    
    // Agua interior
    final innerRect = Rect.fromCenter(center: Offset(center.dx, center.dy - half * 0.1), width: half * 0.95, height: half * 0.28);
    final innerPaint = Paint()..shader = ui.Gradient.radial(Offset(center.dx, center.dy - half * 0.1), half * 0.5, [Colors.cyanAccent, const Color(0xFF0891B2)]);
    canvas.drawOval(innerRect, innerPaint);
  }
}

class LaserComponent extends PositionComponent with HasGameReference<PoopInvadersFlameGame>, CollisionCallbacks {
  double vy, vx;
  bool fromPlayer;
  String type; // 'normal', 'meteor', 'lightning', 'acid', 'acid_sub'

  LaserComponent({required this.vy, this.vx = 0, required this.fromPlayer, this.type = 'normal'}) {
    double lWidth = 6.0;
    double lHeight = 16.0;
    
    if (!fromPlayer) {
      if (type == 'meteor') { lWidth = 24.0; lHeight = 24.0; }
      else if (type == 'lightning') { lWidth = 7.0; lHeight = 20.0; }
      else if (type == 'acid' || type == 'acid_sub') { lWidth = 10.0; lHeight = 10.0; }
    }
    
    size = Vector2(lWidth, lHeight);
    anchor = Anchor.center;
    add(CircleHitbox(radius: lWidth / 2));
  }

  ui.Image? cachedLaserImage;

  @override
  Future<void> onLoad() async {
    cachedLaserImage = await SpriteRasterizer.rasterize(size.x * 3, size.y * 3, (canvas) {
      _renderLaser(canvas, Offset(size.x * 1.5, size.y * 1.5));
    });
  }

  void _disableAndPool() {
    removeFromParent();
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    double currentVy = vy;
    if (!fromPlayer && game.activeBuffCategory == AchievementCategory.locations) {
      currentVy *= 0.90;
    }

    if (!fromPlayer) {
      if (type == 'lightning') vx = sin(DateTime.now().millisecondsSinceEpoch * 0.02) * 250.0;
      else if (type == 'acid' && position.y >= game.size.y * 0.5) {
        // Divide into 2
        game.spawnLaser(pos: position.clone(), vy: 200.0, vx: -100.0, fromPlayer: false, type: 'acid_sub');
        game.spawnLaser(pos: position.clone(), vy: 200.0, vx: 100.0, fromPlayer: false, type: 'acid_sub');
        game.spawnParticles(position.clone(), '🧪', 5);
        _disableAndPool();
        return;
      }
    }

    position.x += vx * dt;
    position.y += currentVy * dt;

    if (fromPlayer && Random().nextDouble() < 0.22) {
      game.spawnParticles(position.clone(), '✨', 1, speed: 0.3);
    }

    if (position.y < -50 || position.y > game.size.y + 50 || position.x < -50 || position.x > game.size.y + 50) {
      _disableAndPool();
    }
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    
    if (fromPlayer && other is InvaderEnemy) {
      other.hit();
      _disableAndPool();
    } else if (!fromPlayer && other is PlayerShip) {
      if (type == 'meteor') game.spawnParticles(position.clone(), '🔥', 15, speed: 3.0);
      game.hitPlayer();
      _disableAndPool();
    }
  }

  @override
  void render(Canvas canvas) {
    if (cachedLaserImage != null) {
      canvas.drawImage(cachedLaserImage!, Offset(-size.x, -size.y), Paint());
    } else {
      _renderLaser(canvas, Offset(size.x / 2, size.y / 2));
    }
  }

  void _renderLaser(Canvas canvas, Offset lCenter) {
    Color laserColor = fromPlayer ? Colors.cyanAccent : Colors.purpleAccent;
    if (!fromPlayer) {
      if (type == 'meteor') laserColor = Colors.orangeAccent;
      else if (type == 'lightning') laserColor = Colors.cyanAccent;
      else if (type == 'acid' || type == 'acid_sub') laserColor = Colors.greenAccent[400]!;
    }

    final glowPaint = Paint()..color = laserColor.withAlpha(100)..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);

    if (type == 'meteor') {
      canvas.drawCircle(lCenter, size.x / 2 + 3, glowPaint);
      canvas.drawCircle(lCenter, size.x / 2, Paint()..shader = ui.Gradient.radial(lCenter, size.x / 2, [Colors.yellow, Colors.orangeAccent[700]!]));
    } else if (type == 'acid' || type == 'acid_sub') {
      canvas.drawCircle(lCenter, size.x / 2 + 2, glowPaint);
      canvas.drawCircle(lCenter, size.x / 2, Paint()..color = Colors.greenAccent[400]!);
    } else {
      // Trail
      final trailPaint = Paint()..shader = ui.Gradient.linear(Offset(lCenter.dx, lCenter.dy - size.y / 2), Offset(lCenter.dx, lCenter.dy + size.y * 2.0 * (fromPlayer ? 1 : -1)), [laserColor.withAlpha(180), laserColor.withAlpha(0)]);
      canvas.drawRect(Rect.fromCenter(center: Offset(lCenter.dx, lCenter.dy + size.y * 0.8 * (fromPlayer ? 1 : -1)), width: size.x * 0.6, height: size.y * 2.0), trailPaint);

      canvas.drawOval(Rect.fromCenter(center: lCenter, width: size.x, height: size.y), glowPaint);
      canvas.drawOval(Rect.fromCenter(center: lCenter, width: size.x / 2, height: size.y * 0.75), Paint()..color = Colors.white);
    }
  }
}

class InvaderEnemy extends PositionComponent with HasGameReference<PoopInvadersFlameGame>, CollisionCallbacks {
  String type;
  String bossType;
  String visualType;
  int hp;
  int maxHp;
  Vector2 velocity = Vector2.zero();
  
  double time = 0;
  double bossAttackTimer = 0;

  ui.Image? cachedEnemyImage;
  ui.Image? cachedDamagedEnemyImage;
  double hitFlashTimer = 0.0;

  InvaderEnemy({
    required this.type,
    required this.maxHp,
    required this.bossType,
    required this.visualType,
  }) : hp = maxHp {
    double rSize = type == 'boss' ? 54.0 : (type == 'ufo' ? 40.0 : 22.0);
    size = Vector2(rSize, rSize);
    anchor = Anchor.center;
    add(CircleHitbox(radius: rSize / 2));
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // El buffer medirá size.x * 2 para evitar recortes visuales de cilios/antenas/formas anchas
    cachedEnemyImage = await SpriteRasterizer.rasterize(size.x * 2, size.y * 2, (canvas) {
      _drawEnemyVector(canvas, Offset(size.x, size.y), size.x / 2, isDamaged: false);
    });

    if (visualType == 'alien' || type == 'boss') {
      cachedDamagedEnemyImage = await SpriteRasterizer.rasterize(size.x * 2, size.y * 2, (canvas) {
        _drawEnemyVector(canvas, Offset(size.x, size.y), size.x / 2, isDamaged: true);
      });
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    time += dt;

    if (hitFlashTimer > 0) {
      hitFlashTimer -= dt;
    }

    if (type == 'boss') {
      double healthPct = hp / maxHp;
      double speedMultiplier = healthPct < 0.4 ? 1.5 : 1.0;
      position.x += velocity.x * speedMultiplier * dt;
    } else if (visualType == 'alien') {
      position.x += velocity.x * dt + sin(time * 5.0) * 1.5;
    } else {
      position.x += velocity.x * dt;
    }

    if (type == 'ufo') {
      if (position.x > game.size.x + 50) removeFromParent();
    } else if (position.x < size.x || position.x > game.size.x - size.x) {
      velocity.x = -velocity.x;
      if (type != 'boss') position.y += 20.0;
      position.x = position.x.clamp(size.x, game.size.x - size.x);
    }

    if (type == 'boss') {
      _bossAttacks(dt);
    } else if (type != 'ufo') {
      // Promedio de disparos por segundo por cada enemigo. En oleada 1: 0.2 tiros/seg.
      double shotsPerSecond = 0.2 + game.wave * 0.05;
      if (Random().nextDouble() < shotsPerSecond * dt) { 
         game.spawnLaser(pos: position.clone()..y += size.y / 2, vy: 200.0, fromPlayer: false);
      }
      if (position.y >= game.size.y * 0.84) {
        game.triggerGameOver();
      }
    }
  }

  void _bossAttacks(double dt) {
    double healthPct = hp / maxHp;
    double attackCooldownMod = healthPct < 0.4 ? 1.6 : 1.0;
    bossAttackTimer += dt * attackCooldownMod;

    if (bossType == 'fire' && bossAttackTimer >= 2.5) {
      bossAttackTimer = 0;
      game.spawnLaser(pos: Vector2(game.player.position.x, position.y + 30), vy: 120.0, fromPlayer: false, type: 'meteor');
      game.addFloatingText('🔥 ¡METEORITO! 🔥', position.clone()..y += 30, Colors.orangeAccent);
    } else if (bossType == 'electric' && bossAttackTimer >= 2.2) {
      bossAttackTimer = 0;
      game.spawnLaser(pos: position.clone()..y += 30, vy: 240.0, fromPlayer: false, type: 'lightning');
      game.addFloatingText('⚡ ¡RÁPIDO ZIGZAG! ⚡', position.clone()..y += 30, Colors.cyanAccent);
    } else if (bossType == 'acid' && bossAttackTimer >= 2.0) {
      bossAttackTimer = 0;
      game.spawnLaser(pos: position.clone()..x += (Random().nextDouble() - 0.5) * 60, vy: 180.0, fromPlayer: false, type: 'acid');
    }

    // El Jefe lanza un láser básico aleatoriamente (~1.2 veces por segundo, o 2.4 si está furioso)
    double baseAttackChance = healthPct < 0.4 ? 2.4 : 1.2;
    if (Random().nextDouble() < baseAttackChance * dt) {
      game.spawnLaser(pos: position.clone()..y += 30, vy: 220.0, fromPlayer: false);
      if (healthPct < 0.4) {
        // Disparos en diagonal extra cuando está furioso
        game.spawnLaser(pos: position.clone()..y += 30, vy: 200.0, vx: -60.0, fromPlayer: false);
        game.spawnLaser(pos: position.clone()..y += 30, vy: 200.0, vx: 60.0, fromPlayer: false);
      }
    }
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is PlayerShip) {
      game.hitPlayer();
      if (type != 'boss') {
        die(silent: true);
      } else {
        position.y -= 30; // Boss rebota para no triturar al jugador de un golpe
      }
    }
  }

  void hit() {
    hp--;
    hitFlashTimer = 0.08;
    game.spawnParticles(position.clone(), '💥', 3, speed: 2.0);
    
    if (hp <= 0) {
      die();
    }
  }

  void die({bool silent = false}) {
    if (!silent) {
      GameAudio.play('explosion.wav', volume: 0.12);
      if (type == 'boss') {
        game.isBossActive = false;
        int reward = 500 + (game.nextBossIndex - 1) * 100;
        game.addScore(reward);
        game.spawnParticles(position.clone(), '🔥', 20, speed: 4.0);
        game.addFloatingText('¡JEFE DEFEATED! +$reward 🏆', position.clone(), Colors.greenAccent, size: 18);
        game.onAddKcoins(80);
        HapticFeedback.heavyImpact();
        game.shakeScreen(duration: 0.5, intensity: 15.0);
      } else if (type == 'ufo') {
        game.addScore(250);
        game.onAddKcoins(50);
        game.spawnParticles(position.clone(), '⭐', 15, speed: 3.5);
        game.addFloatingText('+250 💰', position.clone(), Colors.yellowAccent);
        _dropItem(guaranteed: true);
      } else {
        game.addScore(15);
        game.spawnParticles(position.clone(), '💀', 8, speed: 3.5);
        game.addFloatingText('+15 💀', position.clone(), Colors.greenAccent);
        _dropItem();
      }
    }
    removeFromParent();
  }

  void _dropItem({bool guaranteed = false}) {
    final rand = Random();
    double dropChance = game.activeBuffCategory == AchievementCategory.calendar ? 0.38 : 0.28;
    if (guaranteed || type == 'boss' || rand.nextDouble() < dropChance) {
      String pType = ['triple', 'burst', 'shield', 'life'][rand.nextInt(4)];
      game.add(PowerupItem(type: pType)..position = position.clone());
    }
  }

  @override
  void render(Canvas canvas) {
    // 1. Auras del Boss (se dibujan antes del cuerpo en tiempo real con animación)
    if (type == 'boss') {
      final center = Offset(size.x / 2, size.y / 2);
      final double half = size.x / 2;
      final timeMs = DateTime.now().millisecondsSinceEpoch;
      if (bossType == 'fire') {
        final double wave1 = sin(timeMs * 0.02) * 4.0;
        final double wave2 = cos(timeMs * 0.025) * 3.0;
        final flamePaint = Paint()..shader = ui.Gradient.radial(center, half * 1.5, [Colors.yellow, Colors.orangeAccent, Colors.redAccent, Colors.transparent], [0.0, 0.33, 0.66, 1.0]);
        final flamePath = Path()..moveTo(center.dx - half * 0.9, center.dy)..quadraticBezierTo(center.dx - half * 1.2 + wave1, center.dy - half * 1.2 + wave2, center.dx, center.dy - half * 1.8)..quadraticBezierTo(center.dx + half * 1.2 - wave2, center.dy - half * 1.2 + wave1, center.dx + half * 0.9, center.dy)..close();
        canvas.drawPath(flamePath, flamePaint);
      } else if (bossType == 'electric') {
        final sparkPaint = Paint()..color = Colors.cyanAccent..strokeWidth = 2.0..style = PaintingStyle.stroke;
        final rand = Random(timeMs ~/ 80);
        for (int i = 0; i < 4; i++) {
          double angle = rand.nextDouble() * 2 * pi;
          canvas.drawLine(Offset(center.dx + cos(angle) * half * 0.9, center.dy + sin(angle) * half * 0.9), Offset(center.dx + cos(angle + 0.1) * half * 1.5, center.dy + sin(angle + 0.1) * half * 1.5), sparkPaint);
        }
      } else if (bossType == 'acid') {
        final bubblePaint = Paint()..color = (Colors.greenAccent[400] ?? Colors.greenAccent).withAlpha(160);
        final rand = Random(42);
        for (int i = 0; i < 4; i++) {
          double offsetTime = (timeMs * 0.03 * (0.8 + rand.nextDouble()) + i * 20) % (half * 1.5);
          canvas.drawCircle(Offset(center.dx + (rand.nextDouble() - 0.5) * half * 1.2, center.dy + half * 0.4 + offsetTime), 3, bubblePaint);
        }
      }
    }

    // 2. Dibujar Cuerpo (desde la imagen cacheada)
    var img = cachedEnemyImage;
    if ((visualType == 'alien' || type == 'boss') && hp < maxHp && cachedDamagedEnemyImage != null) {
      img = cachedDamagedEnemyImage;
    }

    if (img != null) {
      final paint = Paint();
      if (hitFlashTimer > 0) {
        paint.colorFilter = const ColorFilter.mode(Colors.white, BlendMode.srcATop);
      }
      // Dibuja la imagen cacheada de 2x tamaño centrada en la posición del componente
      canvas.drawImage(img, Offset(-size.x / 2, -size.y / 2), paint);
    }

    // 3. Barra de vida del Boss (se dibuja encima del cuerpo)
    if (type == 'boss') {
      final center = Offset(size.x / 2, size.y / 2);
      final barRect = Rect.fromCenter(center: Offset(center.dx, center.dy - 44), width: 60, height: 6);
      canvas.drawRRect(RRect.fromRectAndRadius(barRect, const Radius.circular(3)), Paint()..color = Colors.black54);
      double lifePct = (hp / maxHp).clamp(0.0, 1.0);
      final lifeRect = Rect.fromLTWH(barRect.left, barRect.top, 60 * lifePct, 6);
      Color hpColor = Colors.redAccent;
      if (bossType == 'electric') hpColor = Colors.cyanAccent;
      if (bossType == 'acid') hpColor = Colors.greenAccent[400] ?? Colors.greenAccent;
      canvas.drawRRect(RRect.fromRectAndRadius(lifeRect, const Radius.circular(3)), Paint()..color = hpColor);
    }
  }

  void _drawEnemyVector(Canvas canvas, Offset center, double half, {required bool isDamaged}) {
    if (type == 'ufo') {
      final goldPaint = Paint()..shader = ui.Gradient.linear(Offset(center.dx - half, center.dy - half), Offset(center.dx + half, center.dy + half), [Colors.yellow, Colors.orangeAccent, Colors.yellowAccent], [0.0, 0.5, 1.0]);
      final ufoPath = Path()..moveTo(center.dx - half * 1.5, center.dy)..quadraticBezierTo(center.dx, center.dy - half, center.dx + half * 1.5, center.dy)..quadraticBezierTo(center.dx, center.dy + half * 0.8, center.dx - half * 1.5, center.dy);
      canvas.drawPath(ufoPath, goldPaint);
      canvas.drawPath(ufoPath, Paint()..color = Colors.white24..style = PaintingStyle.stroke..strokeWidth = 2);
      canvas.drawCircle(Offset(center.dx, center.dy - half * 0.4), half * 0.6, Paint()..color = Colors.cyanAccent.withAlpha(150));
      return;
    }

    Color color1 = Colors.brown[400] ?? Colors.brown;
    Color color2 = Colors.brown[800] ?? Colors.brown;
    if (type == 'fast') { color1 = Colors.greenAccent[400] ?? Colors.greenAccent; color2 = Colors.teal[900] ?? Colors.teal; }
    else if (type == 'boss') {
      if (bossType == 'fire') { color1 = Colors.orangeAccent[700] ?? Colors.orangeAccent; color2 = const Color(0xFF6F0000); }
      else if (bossType == 'electric') { color1 = Colors.cyanAccent[400] ?? Colors.cyanAccent; color2 = const Color(0xFF003050); }
      else if (bossType == 'acid') { color1 = Colors.greenAccent[400] ?? Colors.greenAccent; color2 = const Color(0xFF004400); }
    }

    if (type == 'boss' || visualType == 'poop') {
      final poopPaint = Paint()..shader = ui.Gradient.radial(Offset(center.dx - half * 0.15, center.dy - half * 0.2), half * 1.1, [color1, color2]);
      final strokePaint = Paint()..color = const Color(0xFF3B2314)..style = PaintingStyle.stroke..strokeWidth = type == 'boss' ? 2.5 : 1.2;

      final baseRect = Rect.fromCenter(center: Offset(center.dx, center.dy + half * 0.4), width: half * 1.7, height: half * 0.55);
      canvas.drawOval(baseRect, poopPaint); canvas.drawOval(baseRect, strokePaint);

      final midRect = Rect.fromCenter(center: Offset(center.dx, center.dy + half * 0.02), width: half * 1.3, height: half * 0.48);
      canvas.drawOval(midRect, poopPaint); canvas.drawOval(midRect, strokePaint);

      final topRect = Rect.fromCenter(center: Offset(center.dx, center.dy - half * 0.32), width: half * 0.85, height: half * 0.42);
      canvas.drawOval(topRect, poopPaint); canvas.drawOval(topRect, strokePaint);

      // Antena del boss
      canvas.save();
      canvas.translate(center.dx, center.dy - half * 0.5);
      canvas.drawLine(Offset.zero, const Offset(0, -9), Paint()..color = Colors.grey[400]!..strokeWidth = 1.5);
      canvas.drawCircle(const Offset(0, -10), 3.0, Paint()..color = Colors.greenAccent);
      canvas.restore();

      final eyePaint = Paint()..color = type == 'boss' ? Colors.yellowAccent : Colors.redAccent;
      final pupilPaint = Paint()..color = type == 'boss' ? Colors.red : Colors.white;

      if (type == 'boss') {
        canvas.drawCircle(Offset(center.dx - 12, center.dy - 2), 7, eyePaint); canvas.drawCircle(Offset(center.dx - 12, center.dy - 2), 2, pupilPaint);
        canvas.drawCircle(Offset(center.dx + 12, center.dy - 2), 7, eyePaint); canvas.drawCircle(Offset(center.dx + 12, center.dy - 2), 2, pupilPaint);
        canvas.drawCircle(Offset(center.dx, center.dy - 10), 8, eyePaint); canvas.drawCircle(Offset(center.dx, center.dy - 10), 3, pupilPaint);
      } else {
        canvas.drawCircle(Offset(center.dx - half * 0.3, center.dy + 2), 3.5, eyePaint); canvas.drawCircle(Offset(center.dx - half * 0.3, center.dy + 2), 1.0, pupilPaint);
        canvas.drawCircle(Offset(center.dx + half * 0.3, center.dy + 2), 3.5, eyePaint); canvas.drawCircle(Offset(center.dx + half * 0.3, center.dy + 2), 1.0, pupilPaint);
      }
    } else if (visualType == 'bacteria') {
      final cilioPaint = Paint()..color = Colors.purpleAccent.withAlpha(200);
      for (int i = 0; i < 10; i++) {
        double angle = i * 2 * pi / 10;
        double radiusOffset = half * 1.12;
        canvas.drawCircle(Offset(center.dx + cos(angle) * radiusOffset, center.dy + sin(angle) * radiusOffset), 3, cilioPaint);
      }
      canvas.drawCircle(center, half * 0.95, Paint()..shader = ui.Gradient.radial(Offset(center.dx - 2, center.dy - 2), half * 0.95, [Colors.purpleAccent, Colors.purple[900]!]));
      canvas.drawCircle(center, half * 0.95, Paint()..color = Colors.purple[800]!..style = PaintingStyle.stroke..strokeWidth = 1.2);
      canvas.drawCircle(center, half * 0.35, Paint()..color = Colors.cyanAccent.withAlpha(180));
      canvas.drawCircle(center, half * 0.15, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(center.dx - half * 0.35, center.dy - half * 0.2), 3, Paint()..color = Colors.redAccent);
      canvas.drawCircle(Offset(center.dx + half * 0.35, center.dy - half * 0.2), 3, Paint()..color = Colors.redAccent);
    } else if (visualType == 'alien') {
      final aliColor1 = isDamaged ? Colors.orangeAccent : (Colors.greenAccent[400] ?? Colors.greenAccent);
      final aliColor2 = isDamaged ? (Colors.red[900] ?? Colors.red) : (Colors.green[900] ?? Colors.green);
      final headPaint = Paint()..shader = ui.Gradient.radial(Offset(center.dx - 2, center.dy - 3), half * 1.05, [aliColor1, aliColor2]);
      final alienPath = Path()
        ..moveTo(center.dx - half * 0.75, center.dy - half * 0.3)
        ..cubicTo(center.dx - half * 0.85, center.dy - half * 0.95, center.dx + half * 0.85, center.dy - half * 0.95, center.dx + half * 0.75, center.dy - half * 0.3)
        ..cubicTo(center.dx + half * 0.65, center.dy + half * 0.35, center.dx + half * 0.3, center.dy + half * 0.75, center.dx, center.dy + half * 0.75)
        ..cubicTo(center.dx - half * 0.3, center.dy + half * 0.75, center.dx - half * 0.65, center.dy + half * 0.35, center.dx - half * 0.75, center.dy - half * 0.3)..close();
      canvas.drawPath(alienPath, headPaint);
      canvas.drawPath(alienPath, Paint()..color = const Color(0xFF0F172A)..style = PaintingStyle.stroke..strokeWidth = 1.2);

      final eyePaint = Paint()..color = const Color(0xFF020617);
      canvas.save(); canvas.translate(center.dx - half * 0.3, center.dy - half * 0.05); canvas.rotate(0.22);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: half * 0.45, height: half * 0.75), eyePaint); canvas.drawCircle(const Offset(-1.5, -2), 1.5, Paint()..color = Colors.white); canvas.restore();
      canvas.save(); canvas.translate(center.dx + half * 0.3, center.dy - half * 0.05); canvas.rotate(-0.22);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: half * 0.45, height: half * 0.75), eyePaint); canvas.drawCircle(const Offset(1.5, -2), 1.5, Paint()..color = Colors.white); canvas.restore();

      canvas.drawLine(Offset(center.dx, center.dy - half * 0.8), Offset(center.dx, center.dy - half * 1.15), Paint()..color = Colors.grey[400]!..strokeWidth = 1.2);
      canvas.drawCircle(Offset(center.dx, center.dy - half * 1.2), 2.5, Paint()..color = Colors.greenAccent);
    }
  }
}

class PowerupItem extends PositionComponent with HasGameReference<PoopInvadersFlameGame>, CollisionCallbacks {
  final String type;
  
  PowerupItem({required this.type}) {
    size = Vector2(28, 28);
    anchor = Anchor.center;
    add(CircleHitbox(radius: 14));
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.y += 100.0 * dt;
    if (position.y > game.size.y + 50) removeFromParent();
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is PlayerShip) {
      HapticFeedback.heavyImpact();
      game.spawnParticles(position.clone(), '⭐', 15);
      
      if (type == 'triple') {
        other.tripleShotTime = 6.0;
        game.addFloatingText('¡TRIPLE DISPARO! ⭐', other.position.clone()..y -= 30, Colors.amberAccent);
      } else if (type == 'burst') {
        other.burstShotTime = 6.0;
        game.addFloatingText('¡DISPARO RÁPIDO! ⚡', other.position.clone()..y -= 30, Colors.cyanAccent);
      } else if (type == 'life') {
        game.lives = (game.lives + 1).clamp(0, 5);
        game.onLivesChanged(game.lives);
        game.addFloatingText('+1 VIDA 💖', other.position.clone()..y -= 30, Colors.redAccent);
      } else {
        other.hasShield = true;
        game.addFloatingText('¡ESCUDO ACTIVADO! 🧼', other.position.clone()..y -= 30, Colors.blueAccent);
      }
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    Color itemColor = Colors.amber;
    String emoji = '⭐';
    if (type == 'burst') { itemColor = Colors.cyan; emoji = '⚡'; }
    else if (type == 'shield') { itemColor = Colors.blue; emoji = '🧼'; }
    else if (type == 'life') { itemColor = Colors.redAccent; emoji = '💖'; }

    final center = Offset(size.x / 2, size.y / 2);
    canvas.drawCircle(center, 14, Paint()..color = itemColor.withAlpha(90)..maskFilter = const MaskFilter.blur(BlurStyle.solid, 6));

    final ft = TextPainter(text: TextSpan(text: emoji, style: const TextStyle(fontSize: 16)), textDirection: TextDirection.ltr);
    ft.layout();
    ft.paint(canvas, Offset(center.dx - ft.width / 2, center.dy - ft.height / 2));
  }
}

class FloatingTextComponent extends PositionComponent {
  final String text;
  final Color color;
  final double fontSize;
  double life = 1.0;
  double targetAngle = 0.0;

  FloatingTextComponent({required this.text, required this.color, required this.fontSize}) {
    anchor = Anchor.center;
    targetAngle = (Random().nextDouble() - 0.5) * 0.3;
    angle = targetAngle;
  }

  @override
  void update(double dt) {
    super.update(dt);
    life -= dt;
    position.y -= dt * 45;
    angle = ui.lerpDouble(angle, targetAngle, dt * 5.0) ?? angle;

    double scaleVal = life > 0.8 ? 1.0 + (life - 0.8) * 1.8 : 1.0;
    scale = Vector2.all(scaleVal);

    if (life <= 0) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color.withAlpha((life.clamp(0.0, 1.0) * 255).toInt()), fontSize: fontSize, fontWeight: FontWeight.w900, shadows: const [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1))])),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
  }
}

class GameParticleComponent extends PositionComponent with HasGameReference<PoopInvadersFlameGame> {
  String emoji;
  final double speedMod;
  double vx = 0;
  double vy = 0;
  double life = 1.0;
  double scaleMod = 1.0;

  GameParticleComponent({required this.emoji, required this.speedMod}) {
    reset(speedMod);
  }

  void reset(double speed) {
    final rand = Random();
    vx = (rand.nextDouble() - 0.5) * 300 * speed;
    vy = (rand.nextDouble() - 0.5) * 300 * speed;
    scaleMod = 0.5 + rand.nextDouble() * 0.5;
    life = 1.0;
  }

  void _disableAndPool() {
    removeFromParent();
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.x += vx * dt;
    position.y += vy * dt;
    life -= dt * 2.0; // Desaparece rápido
    if (life <= 0) _disableAndPool();
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.scale(scaleMod);
    final pPainter = TextPainter(text: TextSpan(text: emoji, style: TextStyle(fontSize: 16, color: Colors.white.withAlpha((life.clamp(0.0, 1.0) * 255).toInt()))), textDirection: TextDirection.ltr);
    pPainter.layout();
    pPainter.paint(canvas, Offset(-pPainter.width / 2, -pPainter.height / 2));
    canvas.restore();
  }
}
