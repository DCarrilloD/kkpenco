import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';
import 'package:flame_audio/flame_audio.dart';
import '../shared_game_components.dart' show PoopSkinDrawer, GameAudio;
import '../../../models/achievement.dart';
import 'sprite_rasterizer.dart';

class FlappyPoopFlameGame extends FlameGame with TapCallbacks, HasCollisionDetection {
  final String equippedSkin;
  final bool hasInitialSoapShield;
  final bool hasLifeInsurance;
  final AchievementCategory? activeBuffCategory;
  
  final Function(int) onGameOver;
  final Function(int) onAddKcoins;
  final Function(int) onScoreChanged;
  final Function(int) onLevelChanged;

  late PoopPlayer player;
  late ParallaxBackground background;
  
  int score = 0;
  int level = 1;
  double pipeSpeed = 160.0;
  double distanceSinceLastPipe = 0.0;
  double pipeSpawnDistance = 220.0; // Distancia entre tuberías

  FlappyPoopFlameGame({
    required this.equippedSkin,
    required this.hasInitialSoapShield,
    required this.hasLifeInsurance,
    required this.activeBuffCategory,
    required this.onGameOver,
    required this.onAddKcoins,
    required this.onScoreChanged,
    required this.onLevelChanged,
  });

  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    await FlameAudio.audioCache.loadAll(['jump.wav', 'hit.wav']);
    
    // Añadir fondo
    background = ParallaxBackground();
    add(background);

    // Añadir tuberías iniciales
    _spawnPipe(size.x + 100);
    _spawnPipe(size.x + 100 + pipeSpawnDistance);

    // Añadir jugador
    bool hasShield = hasInitialSoapShield || hasLifeInsurance || activeBuffCategory == AchievementCategory.games;
    player = PoopPlayer(skin: equippedSkin, hasShield: hasShield);
    player.position = Vector2(115.0, 200.0);
    add(player);
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // Control de nivel
    int newLevel = 1 + (score ~/ 8);
    if (newLevel != level) {
      level = newLevel;
      onLevelChanged(level);
      pipeSpeed = 160.0 + (level * 20.0);
    }

    // Spawner de tuberías
    distanceSinceLastPipe += pipeSpeed * dt;
    if (distanceSinceLastPipe > pipeSpawnDistance) {
      _spawnPipe(size.x + 50);
      distanceSinceLastPipe = 0;
    }
  }

  void _spawnPipe(double xPos) {
    final rand = Random();
    final gapY = 80.0 + rand.nextDouble() * (size.y - 250.0).clamp(100.0, 300.0);
    
    final pipe = PipePair(
      gapY: gapY,
      gapHeight: 125.0,
      hasStar: rand.nextDouble() < 0.40,
    );
    pipe.position = Vector2(xPos, 0);
    add(pipe);
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (!paused) {
      player.jump();
      GameAudio.play('jump.wav', volume: 0.5);
    }
  }

  void handleScore() {
    score++;
    onScoreChanged(score);
    addFloatingText("+1", player.position.clone()..add(Vector2(20, 0)), Colors.deepPurpleAccent, size: 18);
  }

  void handleStar() {
    onAddKcoins(5);
    addFloatingText("+5 K\$", player.position.clone(), Colors.amber, size: 16);
  }

  void triggerGameOver() {
    pauseEngine();
    onGameOver(score);
  }

  void addFloatingText(String text, Vector2 pos, Color color, {double size = 14.0}) {
    add(FloatingTextComponent(text: text, color: color, fontSize: size)..position = pos);
  }
}

// --- COMPONENTES ---

class ParallaxBackground extends PositionComponent with HasGameReference<FlappyPoopFlameGame> {
  double bgX = 0;
  
  @override
  void update(double dt) {
    super.update(dt);
    bgX = (bgX - 25.0 * dt) % game.size.x;
  }

  @override
  void render(Canvas canvas) {
    // 1. Gradiente de fondo según el nivel
    Color skyTop;
    Color skyBottom;
    if (game.level == 1) {
      skyTop = Colors.blue[900]!;
      skyBottom = Colors.lightBlue[400]!;
    } else if (game.level == 2) {
      skyTop = const Color(0xFF1E1B4B);
      skyBottom = const Color(0xFFD97706);
    } else if (game.level == 3) {
      skyTop = const Color(0xFF030712);
      skyBottom = const Color(0xFF4C1D95);
    } else {
      skyTop = const Color(0xFF450A0A);
      skyBottom = const Color(0xFF0F172A);
    }

    final bgPaint = Paint()
      ..shader = ui.Gradient.linear(Offset.zero, Offset(0, game.size.y), [skyTop, skyBottom]);
    canvas.drawRect(Rect.fromLTWH(0, 0, game.size.x, game.size.y), bgPaint);

    // 2. Estrellas lejanas
    final starsRand = Random(123);
    for (int i = 0; i < 20; i++) {
      double sx = (starsRand.nextDouble() * game.size.x + bgX * 0.2) % game.size.x;
      double sy = starsRand.nextDouble() * game.size.y;
      double size = 0.5 + starsRand.nextDouble() * 1.0;
      double opacity = 0.2 + 0.8 * sin(DateTime.now().millisecondsSinceEpoch * 0.003 + i).abs();
      canvas.drawCircle(Offset(sx, sy), size, Paint()..color = Colors.white.withAlpha((opacity * 255).toInt()));
    }

    // 3. Nubes con parallax
    final cloudPaint = Paint()..color = Colors.white.withAlpha(22);
    for (int i = 0; i < 3; i++) {
      double cloudX = (bgX + (i * game.size.x / 1.5)) % (game.size.x + 120) - 60;
      double cloudY = 50.0 + (i * 40) % 100;
      canvas.drawCircle(Offset(cloudX, cloudY), 24, cloudPaint);
      canvas.drawCircle(Offset(cloudX + 14, cloudY - 4), 20, cloudPaint);
      canvas.drawCircle(Offset(cloudX - 14, cloudY - 4), 20, cloudPaint);
    }

    // 4. Malla/Grid de fondo
    final gridPaint = Paint()..color = Colors.white.withAlpha(12)..strokeWidth = 0.5;
    for (double i = 0; i < game.size.x; i += 40) canvas.drawLine(Offset(i, 0), Offset(i, game.size.y), gridPaint);
    for (double j = 0; j < game.size.y; j += 40) canvas.drawLine(Offset(0, j), Offset(game.size.x, j), gridPaint);
  }
}

class PoopPlayer extends PositionComponent with HasGameReference<FlappyPoopFlameGame>, CollisionCallbacks {
  final String skin;
  bool hasShield;
  
  double velocityY = 0;
  double gravity = 600.0;
  double jumpForce = -300.0;

  ui.Image? cachedPoopImage;

  PoopPlayer({required this.skin, required this.hasShield}) {
    size = Vector2(30, 30);
    anchor = Anchor.center;
    add(CircleHitbox(radius: 14, position: Vector2(1, 1)));
  }

  @override
  Future<void> onLoad() async {
    cachedPoopImage = await SpriteRasterizer.rasterize(32, 32, (canvas) {
      PoopSkinDrawer.drawPoop(canvas, const Offset(16, 16), 32.0, skin: skin);
    });
  }

  @override
  void onMount() {
    super.onMount();
    if (game.activeBuffCategory == AchievementCategory.locations) gravity *= 0.90;
    if (game.activeBuffCategory == AchievementCategory.stats) jumpForce -= 50.0;
  }

  void jump() {
    velocityY = jumpForce;
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    velocityY += gravity * dt;
    position.y += velocityY * dt;
    
    // Rotación basada en velocidad (clásico Flappy Bird)
    angle = (velocityY * 0.002).clamp(-0.4, 1.1);

    // Límites de pantalla
    if (position.y < 15) {
      position.y = 15;
      velocityY = 0;
    }
    if (position.y > game.size.y - 15) {
      game.triggerGameOver();
    }
  }

  @override
  void render(Canvas canvas) {
    // Escudo
    if (hasShield) {
      final shieldPaint = Paint()..color = Colors.blueAccent.withAlpha(70)..style = PaintingStyle.fill;
      final borderPaint = Paint()..color = Colors.blueAccent..style = PaintingStyle.stroke..strokeWidth = 2;
      canvas.drawCircle(Offset(size.x / 2, size.y / 2), 22, shieldPaint);
      canvas.drawCircle(Offset(size.x / 2, size.y / 2), 22, borderPaint);
    }
    
    if (cachedPoopImage != null) {
      canvas.drawImage(cachedPoopImage!, Offset(size.x / 2 - 16, size.y / 2 - 16), Paint());
    } else {
      PoopSkinDrawer.drawPoop(canvas, Offset(size.x / 2, size.y / 2), 32.0, skin: skin);
    }
  }

  void breakShield() {
    hasShield = false;
    game.addFloatingText("¡ESCUDO ROTO!", position.clone()..sub(Vector2(0, 20)), Colors.blue);
    GameAudio.play('hit.wav', volume: 0.8);
    velocityY = 0; // Estabiliza un poco el golpe
  }
}

class PipePair extends PositionComponent with HasGameReference<FlappyPoopFlameGame>, CollisionCallbacks {
  double gapY;
  final double gapHeight;
  final bool hasStar;
  
  bool passed = false;
  bool starCollected = false;
  double time = 0;

  late RectangleHitbox topHitbox;
  late RectangleHitbox bottomHitbox;
  CircleHitbox? starHitbox;

  PipePair({required this.gapY, required this.gapHeight, required this.hasStar}) {
    width = 50.0;
  }

  @override
  void onMount() {
    super.onMount();
    height = game.size.y;
    
    // Hitboxes
    topHitbox = RectangleHitbox(size: Vector2(width, gapY), position: Vector2.zero());
    bottomHitbox = RectangleHitbox(size: Vector2(width, height - (gapY + gapHeight)), position: Vector2(0, gapY + gapHeight));
    
    add(topHitbox);
    add(bottomHitbox);
    
    if (hasStar) {
      starHitbox = CircleHitbox(radius: 12, position: Vector2(width / 2 - 12, gapY + gapHeight / 2 - 12));
      add(starHitbox!);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    position.x -= game.pipeSpeed * dt;
    
    // Movimiento vertical en niveles altos
    if (game.level >= 2) {
      time += dt * (1.2 + game.level * 0.2);
      double oldGapY = gapY;
      gapY = 80.0 + (game.size.y - 250.0) / 2 + sin(time) * (20.0 + game.level * 6.0); // Simple onda
      
      // Actualizar hitboxes
      topHitbox.size.y = gapY;
      bottomHitbox.position.y = gapY + gapHeight;
      bottomHitbox.size.y = height - (gapY + gapHeight);
      
      if (starHitbox != null) {
        starHitbox!.position.y = gapY + gapHeight / 2 - 12;
      }
    }

    if (position.x < -width) {
      removeFromParent();
    }
    
    // Puntuación
    if (!passed && position.x + width < game.player.position.x) {
      passed = true;
      game.handleScore();
    }
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is PoopPlayer) {
      // Verificar con qué hitbox chocó usando la posición (rudimentario pero efectivo para esto)
      bool hitStar = false;
      if (starHitbox != null && !starCollected) {
        final starCenter = position.clone()..add(starHitbox!.position)..add(Vector2(12, 12));
        if (other.position.distanceTo(starCenter) < 26.0) {
          hitStar = true;
          starCollected = true;
          game.handleStar();
        }
      }

      if (!hitStar) { // Chocó con una tubería
        if (other.hasShield) {
          other.breakShield();
          passed = true; // No lo matamos, le damos pase libre para este tubo
          topHitbox.removeFromParent();
          bottomHitbox.removeFromParent();
        } else {
          game.triggerGameOver();
        }
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final shadowPaint = Paint()..color = Colors.black.withAlpha(50)..style = PaintingStyle.fill;
    final strokePaint = Paint()..color = const Color(0xFF14532D)..style = PaintingStyle.stroke..strokeWidth = 1.8;

    // Sombra
    canvas.drawRect(Rect.fromLTWH(5, 0, width, gapY), shadowPaint);
    canvas.drawRect(Rect.fromLTWH(5, gapY + gapHeight, width, height - (gapY + gapHeight)), shadowPaint);

    final pipeGrad = ui.Gradient.linear(
      const Offset(0, 0), Offset(width, 0),
      [const Color(0xFF166534), const Color(0xFF22C55E), const Color(0xFF4ADE80), const Color(0xFF166534)],
      [0.0, 0.35, 0.5, 1.0],
    );
    final rimGrad = ui.Gradient.linear(
      const Offset(-3, 0), Offset(width + 3, 0),
      [const Color(0xFF15803D), const Color(0xFF4ADE80), const Color(0xFF86EFAC), const Color(0xFF166534)],
      [0.0, 0.35, 0.5, 1.0],
    );

    final pipePaint = Paint()..shader = pipeGrad;
    final rimPaint = Paint()..shader = rimGrad;

    // Tubería superior
    canvas.drawRect(Rect.fromLTWH(0, 0, width, gapY), pipePaint);
    canvas.drawRect(Rect.fromLTWH(-3, gapY - 18, width + 6, 18), rimPaint);
    canvas.drawRect(Rect.fromLTWH(0, 0, width, gapY), strokePaint);
    canvas.drawRect(Rect.fromLTWH(-3, gapY - 18, width + 6, 18), strokePaint);

    // Tubería inferior
    canvas.drawRect(Rect.fromLTWH(0, gapY + gapHeight, width, height - (gapY + gapHeight)), pipePaint);
    canvas.drawRect(Rect.fromLTWH(-3, gapY + gapHeight, width + 6, 18), rimPaint);
    canvas.drawRect(Rect.fromLTWH(0, gapY + gapHeight, width, height - (gapY + gapHeight)), strokePaint);
    canvas.drawRect(Rect.fromLTWH(-3, gapY + gapHeight, width + 6, 18), strokePaint);

    // Estrella
    if (hasStar && !starCollected) {
      final starCenter = Offset(width / 2, gapY + gapHeight / 2);
      canvas.drawCircle(starCenter, 12, Paint()..color = Colors.amber.withAlpha(80)..maskFilter = const MaskFilter.blur(BlurStyle.solid, 6));
      final starPainter = TextPainter(text: const TextSpan(text: '⭐', style: TextStyle(fontSize: 20)), textDirection: TextDirection.ltr)..layout();
      starPainter.paint(canvas, Offset(starCenter.dx - starPainter.width / 2, starCenter.dy - starPainter.height / 2));
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
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color.withAlpha((life.clamp(0.0, 1.0) * 255).toInt()),
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          shadows: const [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1))],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
  }
}
