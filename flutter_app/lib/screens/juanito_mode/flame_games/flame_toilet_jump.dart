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

enum PlatformType { normal, moving, fragile, superSpring }
enum ItemType { none, spring, jetpack, balloon }

class ToiletJumpFlameGame extends FlameGame with TapCallbacks, HasCollisionDetection, HorizontalDragDetector {
  final String equippedSkin;
  final bool hasInitialSpring;
  final bool hasInitialSoapShield;
  final AchievementCategory? activeBuffCategory;
  
  final Function(int, int) onGameOver;
  final Function(int) onScoreChanged;
  final Function(int) onLevelChanged;

  late JumpingPoop player;
  late ParallaxSky sky;
  late CameraComponent cameraComponent;
  late World world;

  int score = 0;
  int level = 1;
  int coinsEarned = 0;

  double maxHeightReached = 0;
  double highestPlatformY = 0;

  // Variables for drag control
  double horizontalVelocity = 0;

  ui.Image? cachedBacteriaImage;

  ToiletJumpFlameGame({
    required this.equippedSkin,
    required this.hasInitialSpring,
    required this.hasInitialSoapShield,
    required this.activeBuffCategory,
    required this.onGameOver,
    required this.onScoreChanged,
    required this.onLevelChanged,
  });

  @override
  Future<void> onLoad() async {
    super.onLoad();

    await FlameAudio.audioCache.loadAll(['jump.wav', 'coin.wav', 'hit.wav']);

    cachedBacteriaImage = await SpriteRasterizer.rasterize(30, 30, (canvas) {
      final center = const Offset(15, 15);
      final half = 15.0;
      final paint = Paint()
        ..shader = ui.Gradient.radial(Offset(center.dx - 3, center.dy - 3), half, [Colors.purpleAccent[200]!, Colors.purple[800]!]);
      
      final path = Path();
      final points = 10;
      final angleStep = (2 * pi) / points;
      for (int i = 0; i < points; i++) {
        double angle = i * angleStep;
        double r = half + (i % 2 == 0 ? 2.0 : -1.0);
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
      canvas.drawCircle(Offset(center.dx - 4.5, center.dy - 1.5), 3.0, eyePaint);
      canvas.drawCircle(Offset(center.dx - 5.5, center.dy - 2.5), 1.0, pupilPaint);
      canvas.drawCircle(Offset(center.dx + 4.5, center.dy - 1.5), 3.0, eyePaint);
      canvas.drawCircle(Offset(center.dx + 3.5, center.dy - 2.5), 1.0, pupilPaint);
    });

    world = World();
    cameraComponent = CameraComponent(world: world)..viewfinder.anchor = Anchor.center;
    
    add(world);
    add(cameraComponent);

    sky = ParallaxSky();
    world.add(sky);

    // Initial platforms
    world.add(JumpPlatform(xPos: 150, yPos: 350, type: PlatformType.normal, item: ItemType.none));
    highestPlatformY = 350;

    for (int i = 0; i < 15; i++) {
      _spawnPlatform(highestPlatformY - 65.0);
    }

    bool hasJetpackStart = hasInitialSoapShield || activeBuffCategory == AchievementCategory.games;
    player = JumpingPoop(skin: equippedSkin, startJetpack: hasJetpackStart, startSuperJump: hasInitialSpring);
    player.position = Vector2(150, 280);
    world.add(player);

    cameraComponent.follow(player, horizontalOnly: false, verticalOnly: true);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Update max height for score and level
    if (player.position.y < maxHeightReached) {
      maxHeightReached = player.position.y;
      
      int currentHeightScore = (-maxHeightReached ~/ 50).toInt() + 10;
      if (currentHeightScore > score) {
        score = currentHeightScore;
        onScoreChanged(score);

        int newLevel = 1;
        if (score > 1000) newLevel = 4;
        else if (score > 500) newLevel = 3;
        else if (score > 200) newLevel = 2;

        if (newLevel != level) {
          level = newLevel;
          onLevelChanged(level);
        }
      }
    }

    // Spawn platforms as player goes up
    if (player.position.y < highestPlatformY + size.y) {
      _spawnPlatform(highestPlatformY - 65.0);
    }

    // Fall off the bottom -> Game Over
    if (player.position.y > cameraComponent.viewfinder.position.y + size.y / 2 + 50) {
      triggerGameOver();
    }
  }

  void _spawnPlatform(double targetY) {
    highestPlatformY = targetY;
    final rand = Random();
    const pWidth = 55.0;
    final pX = rand.nextDouble() * (size.x - pWidth - 20) + 10;
    final rVal = rand.nextDouble();
    
    PlatformType type = PlatformType.normal;
    double relY = targetY; // For calculations

    if (rVal < 0.12 && relY < 150) type = PlatformType.fragile;
    else if (rVal < 0.28 && relY < 200) type = PlatformType.moving;
    else if (rVal < 0.38 && relY < -100) type = PlatformType.superSpring;

    ItemType item = ItemType.none;
    if (type == PlatformType.normal && relY < 250) {
      final iVal = rand.nextDouble();
      final double probMult = activeBuffCategory == AchievementCategory.calendar ? 1.20 : 1.0;
      if (iVal < 0.10 * probMult) item = ItemType.spring;
      else if (iVal < 0.14 * probMult && relY < -100) item = ItemType.jetpack;
      else if (iVal < 0.22 * probMult && relY < 0) item = ItemType.balloon;
    }

    world.add(JumpPlatform(xPos: pX, yPos: targetY, type: type, item: item));

    // Spawn Bacteria
    if (relY < 100 && rand.nextDouble() < 0.15) {
      world.add(BacteriaEnemy(
        xPos: rand.nextDouble() * (size.x - 40) + 10,
        yPos: targetY - 35.0,
        startVx: (rand.nextBool() ? 1.0 : -1.0) * (50.0 + rand.nextDouble() * 30.0),
      ));
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (!paused) player.performDoubleJump();
  }

  @override
  void onHorizontalDragUpdate(DragUpdateInfo info) {
    // Translating drag to horizontal velocity or direct position adjustment
    player.position.x += info.delta.global.x * 1.5;
  }

  void triggerGameOver() {
    GameAudio.play('hit.wav', volume: 0.8);
    pauseEngine();
    HapticFeedback.vibrate();
    onGameOver(score, coinsEarned);
  }

  void addFloatingText(String text, Vector2 pos, Color color) {
    world.add(FloatingTextComponent(text: text, color: color, fontSize: 14)..position = pos);
  }
}

// --- COMPONENTS ---

class ParallaxSky extends PositionComponent with HasGameReference<ToiletJumpFlameGame> {
  @override
  void render(Canvas canvas) {
    final camY = game.cameraComponent.viewfinder.position.y;
    final heightClimbed = -camY;
    
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
    
    // Draw sky based on viewport bounds
    final rect = Rect.fromCenter(
      center: Offset(game.size.x / 2, camY),
      width: game.size.x + 500,
      height: game.size.y + 500,
    );
    
    final skyPaint = Paint()..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, [skyTop, skyBottom]);
    canvas.drawRect(rect, skyPaint);

    // Draw stars
    final starsRand = Random(42);
    for (int i = 0; i < 35; i++) {
      double sx = (starsRand.nextDouble() * game.size.x * 3) - game.size.x;
      double sy = camY - game.size.y / 2 + (starsRand.nextDouble() * game.size.y);
      double size = 0.5 + starsRand.nextDouble() * 1.5;
      double opacity = 0.3 + 0.7 * sin(DateTime.now().millisecondsSinceEpoch * 0.003 + i).abs();
      canvas.drawCircle(Offset(sx, sy), size, Paint()..color = Colors.white.withAlpha((opacity * 255).toInt()));
    }
  }
}

class JumpingPoop extends PositionComponent with HasGameReference<ToiletJumpFlameGame>, CollisionCallbacks {
  final String skin;
  
  double velocityY = 0;
  double gravity = 350.0; // Píxeles por segundo^2
  
  bool hasJetpack = false;
  double jetpackTime = 0;
  
  bool hasBalloon = false;
  double balloonTime = 0;

  int availableDoubleJumps = 1;
  double scaleModX = 1.0;
  double scaleModY = 1.0;

  ui.Image? cachedPoopImage;

  JumpingPoop({required this.skin, bool startJetpack = false, bool startSuperJump = false}) {
    size = Vector2(30, 30);
    anchor = Anchor.center;
    add(CircleHitbox(radius: 15));
    
    if (startJetpack) activateJetpack();
    else if (startSuperJump) velocityY = -500.0;
    else velocityY = -280.0;
  }

  @override
  Future<void> onLoad() async {
    cachedPoopImage = await SpriteRasterizer.rasterize(32, 32, (canvas) {
      PoopSkinDrawer.drawPoop(canvas, const Offset(16, 16), 30.0, skin: skin);
    });
  }

  @override
  void onMount() {
    super.onMount();
    if (game.activeBuffCategory == AchievementCategory.locations) gravity *= 0.90;
  }

  void performDoubleJump() {
    if (hasJetpack || hasBalloon) return;
    if (availableDoubleJumps > 0) {
      availableDoubleJumps--;
      velocityY = -350.0;
      scaleModX = 1.45;
      scaleModY = 0.55;
      game.addFloatingText('¡DOBLE SALTO!', position.clone()..sub(Vector2(0, 20)), Colors.cyanAccent);
      GameAudio.play('jump.wav', volume: 0.6);
      HapticFeedback.mediumImpact();
    }
  }

  void activateJetpack() {
    hasJetpack = true;
    jetpackTime = 2.0;
    game.addFloatingText('¡JETPACK!', position.clone()..sub(Vector2(0, 20)), Colors.blueAccent);
    GameAudio.play('coin.wav', volume: 0.7);
    HapticFeedback.heavyImpact();
  }

  void activateBalloon() {
    hasBalloon = true;
    balloonTime = 4.0;
    game.addFloatingText('¡GLOBO!', position.clone()..sub(Vector2(0, 20)), Colors.greenAccent);
    GameAudio.play('coin.wav', volume: 0.7);
    HapticFeedback.heavyImpact();
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Recovery of squash & stretch
    scaleModX += (1.0 - scaleModX) * 5.0 * dt;
    scaleModY += (1.0 - scaleModY) * 5.0 * dt;

    if (hasJetpack) {
      jetpackTime -= dt;
      velocityY = -450.0;
      if (jetpackTime <= 0) hasJetpack = false;
    } else if (hasBalloon) {
      balloonTime -= dt;
      velocityY = -200.0;
      if (balloonTime <= 0) hasBalloon = false;
    } else {
      velocityY += gravity * dt;
    }

    position.y += velocityY * dt;

    // Wrap around screen X
    if (position.x < 5) position.x = game.size.x - 5;
    if (position.x > game.size.x - 5) position.x = 5;
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.scale(scaleModX, scaleModY);
    
    if (hasJetpack) {
      canvas.drawCircle(Offset.zero, 20, Paint()..color = Colors.blueAccent.withAlpha(60));
    }
    if (hasBalloon) {
      final linePaint = Paint()..color = Colors.white70..strokeWidth = 1.0;
      canvas.drawLine(const Offset(0, -10), const Offset(12, -32), linePaint);
      final gWidth = 14.0;
      final gHeight = 18.0;
      final gx = 12.0;
      final gy = -42.0;
      final balloonPaint = Paint()..shader = ui.Gradient.radial(Offset(gx - 2, gy - 3), gWidth, [Colors.red[300]!, Colors.red[700]!]);
      canvas.drawOval(Rect.fromCenter(center: Offset(gx, gy), width: gWidth, height: gHeight), balloonPaint);
    }

    if (cachedPoopImage != null) {
      canvas.drawImage(cachedPoopImage!, const Offset(-16, -16), Paint());
    } else {
      PoopSkinDrawer.drawPoop(canvas, Offset.zero, 30.0, skin: skin);
    }
    
    canvas.restore();
  }
}

class JumpPlatform extends PositionComponent with HasGameReference<ToiletJumpFlameGame>, CollisionCallbacks {
  final PlatformType type;
  final ItemType item;
  bool broken = false;
  bool itemUsed = false;
  double platformVx = 100.0;
  double springScale = 1.0;

  JumpPlatform({required double xPos, required double yPos, required this.type, required this.item}) {
    position = Vector2(xPos, yPos);
    size = Vector2(55, 10);
    add(RectangleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (broken) return;

    springScale += (1.0 - springScale) * 5.0 * dt;

    if (type == PlatformType.moving) {
      position.x += platformVx * dt;
      if (position.x < 10 || position.x + size.x > game.size.x - 10) {
        platformVx = -platformVx;
      }
    }

    // Garbage collection
    if (position.y > game.cameraComponent.viewfinder.position.y + game.size.y) {
      removeFromParent();
    }
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (broken) return;

    if (other is JumpingPoop) {
      // Solo rebota si está cayendo
      if (other.velocityY > 0) {
        final poopBottom = other.position.y + 15; // aprox radio
        if (poopBottom > position.y && poopBottom < position.y + 20) {
          
          double jumpMultiplier = game.activeBuffCategory == AchievementCategory.stats ? 1.10 : 1.0;

          if (type == PlatformType.fragile) {
            broken = true;
            GameAudio.play('hit.wav', volume: 0.4);
            HapticFeedback.vibrate();
            removeFromParent();
            return; // No bounce
          } else if (type == PlatformType.superSpring) {
            other.velocityY = -550.0 * jumpMultiplier;
            other.scaleModY = 0.3;
            other.scaleModX = 1.7;
            GameAudio.play('jump.wav', volume: 0.4);
            HapticFeedback.heavyImpact();
          } else {
            other.velocityY = -280.0 * jumpMultiplier;
            other.scaleModY = 0.6;
            other.scaleModX = 1.4;
            GameAudio.play('jump.wav', volume: 0.4);
            HapticFeedback.lightImpact();

            // Interacción con ítems
            if (item == ItemType.spring && !itemUsed) {
              itemUsed = true;
              springScale = 0.4;
              other.velocityY = -480.0 * jumpMultiplier;
              GameAudio.play('jump.wav', volume: 0.5);
              HapticFeedback.heavyImpact();
            } else if (item == ItemType.jetpack && !itemUsed) {
              itemUsed = true;
              other.activateJetpack();
            } else if (item == ItemType.balloon && !itemUsed) {
              itemUsed = true;
              other.activateBalloon();
            }
          }
          other.availableDoubleJumps = 1;
        }
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (broken) return;

    Paint pPaint = Paint()..color = Colors.greenAccent[700]!;
    if (type == PlatformType.moving) pPaint.color = Colors.blueAccent[400]!;
    else if (type == PlatformType.fragile) pPaint.color = Colors.brown[600]!;
    else if (type == PlatformType.superSpring) pPaint.color = Colors.redAccent[400]!;

    final rrect = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.x, size.y), const Radius.circular(5));
    canvas.drawRRect(rrect, pPaint);
    canvas.drawRRect(rrect, Paint()..color = Colors.white24..style = PaintingStyle.stroke);

    if (item != ItemType.none && !itemUsed) {
      canvas.save();
      canvas.translate(size.x / 2, -4);
      
      if (item == ItemType.spring) {
        canvas.scale(1.0, springScale);
        final springPaint = Paint()..color = Colors.grey[400]!..strokeWidth = 2.0..style = PaintingStyle.stroke;
        final Path springPath = Path()..moveTo(-6, 0)..lineTo(6, -2)..lineTo(-5, -5)..lineTo(5, -8)..lineTo(-6, -11)..lineTo(6, -13);
        canvas.drawPath(springPath, springPaint);
        canvas.drawRect(const Rect.fromLTWH(-8, -15, 16, 2.5), Paint()..color = Colors.redAccent);
      } else if (item == ItemType.jetpack) {
        canvas.drawRect(const Rect.fromLTWH(-5, -14, 10, 14), Paint()..color = Colors.grey[500]!);
        canvas.drawPath(Path()..moveTo(0, -18)..lineTo(5, -14)..lineTo(-5, -14)..close(), Paint()..color = Colors.redAccent);
      } else if (item == ItemType.balloon) {
        final balloonPaint = Paint()..shader = ui.Gradient.radial(const Offset(-2, -27), 12, [Colors.red[300]!, Colors.red[700]!]);
        canvas.drawOval(Rect.fromCenter(center: const Offset(0, -24), width: 12, height: 16), balloonPaint);
        canvas.drawLine(const Offset(0, -14), const Offset(0, 0), Paint()..color = Colors.white54..strokeWidth = 0.8);
      }
      canvas.restore();
    }
  }
}

class BacteriaEnemy extends PositionComponent with HasGameReference<ToiletJumpFlameGame>, CollisionCallbacks {
  double startVx;
  double time = 0;
  double baseY;
  bool isDead = false;

  BacteriaEnemy({required double xPos, required double yPos, required this.startVx}) : baseY = yPos {
    position = Vector2(xPos, yPos);
    size = Vector2(30, 30);
    add(CircleHitbox(radius: 15));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isDead) return;

    position.x += startVx * dt;
    time += dt * (5.0 + game.level);
    position.y = baseY + sin(time) * (15.0 + game.level * 3);

    if (position.x < 10 || position.x + size.x > game.size.x - 10) {
      startVx = -startVx;
    }

    if (position.y > game.cameraComponent.viewfinder.position.y + game.size.y) {
      removeFromParent();
    }
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (isDead) return;

    if (other is JumpingPoop) {
      bool fromTop = other.velocityY > 0 && other.position.y + 10 < position.y + size.y / 2;

      if (fromTop) {
        isDead = true;
        other.velocityY = -300.0;
        other.availableDoubleJumps = 1;
        game.score += 100;
        game.addFloatingText('+100', position.clone(), Colors.orangeAccent);
        HapticFeedback.mediumImpact();
        removeFromParent(); // Desaparece
      } else {
        // El usuario especificó que Jetpack y Globo NO desactivan la vulnerabilidad
        game.triggerGameOver();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (isDead) return;
    
    if (game.cachedBacteriaImage != null) {
      canvas.drawImage(game.cachedBacteriaImage!, Offset.zero, Paint());
    } else {
      // Fallback vectorial
      final center = Offset(size.x / 2, size.y / 2);
      final half = size.x / 2;
      
      final paint = Paint()
        ..shader = ui.Gradient.radial(Offset(center.dx - 3, center.dy - 3), half, [Colors.purpleAccent[200]!, Colors.purple[800]!]);
      
      final path = Path();
      final points = 10;
      final angleStep = (2 * pi) / points;
      final timeMs = DateTime.now().millisecondsSinceEpoch;
      
      for (int i = 0; i < points; i++) {
        double angle = i * angleStep;
        double wave = sin(timeMs * 0.015 + i) * 2.0;
        double r = half + (i % 2 == 0 ? 4.0 + wave : -1.5);
        double px = center.dx + cos(angle) * r;
        double py = center.dy + sin(angle) * r;
        if (i == 0) path.moveTo(px, py);
        else path.lineTo(px, py);
      }
      path.close();
      canvas.drawPath(path, paint);
      
      // Eyes
      final eyePaint = Paint()..color = Colors.redAccent;
      canvas.drawCircle(Offset(center.dx - half * 0.35, center.dy - half * 0.1), 4.0, eyePaint);
      canvas.drawCircle(Offset(center.dx + half * 0.35, center.dy - half * 0.1), 4.0, eyePaint);
    }
  }
}

class FloatingTextComponent extends PositionComponent {
  final String text;
  final Color color;
  final double fontSize;
  double life = 1.0;

  FloatingTextComponent({required this.text, required this.color, required this.fontSize});

  @override
  void update(double dt) {
    super.update(dt);
    life -= dt;
    position.y -= dt * 50;
    if (life <= 0) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color.withAlpha((life.clamp(0.0, 1.0) * 255).toInt()), fontSize: fontSize, fontWeight: FontWeight.w900)),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
  }
}
