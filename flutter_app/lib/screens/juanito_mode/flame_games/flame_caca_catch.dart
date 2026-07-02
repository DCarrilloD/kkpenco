import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame_audio/flame_audio.dart';
import '../shared_game_components.dart' show GameAudio;
import '../../../models/achievement.dart';
import 'sprite_rasterizer.dart';

// --- ENUMS Y CONSTANTES ---
enum CatchItemType { poop, paper, bacteria, soap, goldenPoop, soda, chlorineBomb }

class CacaCatchFlameGame extends FlameGame with PanDetector, HasCollisionDetection {
  final String equippedSkin;
  final bool hasImprovedMagnet;
  final bool hasInitialSoapShield;
  final bool hasExtraLife;
  final bool hasFeverMagnet;
  final AchievementCategory? activeBuffCategory;
  
  // Callbacks para la UI de Flutter
  final Function(int) onGameOver;
  final Function(int) onAddKcoins;
  final Function(int) onScoreChanged;
  final Function(int) onLivesChanged;
  final Function(bool, double) onFeverChanged; // isFeverMode, progress (0 a 1)

  late ToiletPlayer toilet;
  
  double catchSpawnProb = 0.05;
  double catchSpeed = 150.0; // Píxeles por segundo
  
  int score = 0;
  int lives = 3;
  int level = 1;
  int comboMultiplier = 1;
  int poopsCaughtConsecutively = 0;
  
  bool isFeverMode = false;
  double feverTimeRemaining = 0;
  
  bool isSodaFrenzy = false;
  double sodaFrenzyTimeRemaining = 0;
  
  double timeSinceLastSpawn = 0;

  CacaCatchFlameGame({
    required this.equippedSkin,
    required this.hasImprovedMagnet,
    required this.hasInitialSoapShield,
    required this.hasExtraLife,
    required this.hasFeverMagnet,
    required this.activeBuffCategory,
    required this.onGameOver,
    required this.onAddKcoins,
    required this.onScoreChanged,
    required this.onLivesChanged,
    required this.onFeverChanged,
  });

  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    await FlameAudio.audioCache.loadAll(['coin.wav', 'hit.wav']);
    
    // Configuración inicial
    lives = hasExtraLife ? 4 : 3;
    if (activeBuffCategory == AchievementCategory.games) lives++;
    onLivesChanged(lives);

    // Fondo
    add(BackgroundComponent());

    // Jugador (Inodoro)
    toilet = ToiletPlayer(hasShield: hasInitialSoapShield);
    toilet.position = Vector2(size.x / 2, size.y - 60);
    add(toilet);
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // Lógica de aparición de items
    timeSinceLastSpawn += dt;
    double spawnRate = isSodaFrenzy ? 0.15 : (0.5 - (level * 0.05).clamp(0.0, 0.3));
    
    if (timeSinceLastSpawn > spawnRate) {
      if (Random().nextDouble() < catchSpawnProb * (isSodaFrenzy ? 3 : 1)) {
        _spawnItem();
      }
      timeSinceLastSpawn = 0;
    }

    // Actualizar Fiebre
    if (isFeverMode) {
      feverTimeRemaining -= dt;
      onFeverChanged(true, feverTimeRemaining / 5.0);
      if (feverTimeRemaining <= 0) {
        isFeverMode = false;
        catchSpeed = 150.0 + (level * 20);
        onFeverChanged(false, 0);
      }
    }

    // Actualizar Soda Frenzy
    if (isSodaFrenzy) {
      sodaFrenzyTimeRemaining -= dt;
      if (sodaFrenzyTimeRemaining <= 0) {
        isSodaFrenzy = false;
      }
    }
  }

  void _spawnItem() {
    final rand = Random();
    final xPos = 20 + rand.nextDouble() * (size.x - 40);
    
    CatchItemType type = CatchItemType.poop;
    double r = rand.nextDouble();
    
    if (isFeverMode) {
      if (r < 0.6) type = CatchItemType.goldenPoop;
      else if (r < 0.9) type = CatchItemType.poop;
      else type = CatchItemType.soda;
    } else {
      if (r < 0.50) type = CatchItemType.poop;
      else if (r < 0.70) type = CatchItemType.paper;
      else if (r < 0.85) type = CatchItemType.bacteria;
      else if (r < 0.90) type = CatchItemType.soap;
      else if (r < 0.95) type = CatchItemType.goldenPoop;
      else if (r < 0.98) type = CatchItemType.soda;
      else type = CatchItemType.chlorineBomb;
    }

    final item = FallingItem(type: type, speed: catchSpeed, skin: equippedSkin);
    item.position = Vector2(xPos, -30);
    add(item);
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    // Mover el inodoro de forma relativa o absoluta
    // Para control relativo:
    toilet.position.x += info.delta.global.x * 1.5;
    toilet.position.x = toilet.position.x.clamp(20.0, size.x - 20.0);
  }

  void handleItemCaught(FallingItem item) {
    item.removeFromParent();
    
    if (item.type == CatchItemType.bacteria || item.type == CatchItemType.chlorineBomb) {
      if (toilet.hasShield) {
        toilet.hasShield = false;
        addFloatingText("¡Escudo Roto!", item.position, Colors.blue);
        GameAudio.play('hit.wav', volume: 0.8);
      } else {
        lives--;
        poopsCaughtConsecutively = 0;
        comboMultiplier = 1;
        onLivesChanged(lives);
        addFloatingText("¡Daño!", item.position, Colors.red);
        GameAudio.play('hit.wav', volume: 0.8);
        HapticFeedback.heavyImpact();
        
        if (lives <= 0) {
          onGameOver(score);
          pauseEngine();
        }
      }
    } else {
      // Recompensas
      int points = 10;
      if (item.type == CatchItemType.paper) points = 5;
      if (item.type == CatchItemType.goldenPoop) points = 50;
      if (item.type == CatchItemType.soap) toilet.hasShield = true;
      if (item.type == CatchItemType.soda) {
        isSodaFrenzy = true;
        sodaFrenzyTimeRemaining = 4.0;
        addFloatingText("¡Frenesí!", item.position, Colors.cyan);
      }

      GameAudio.play('coin.wav', volume: 0.6);

      score += points * comboMultiplier;
      onScoreChanged(score);
      addFloatingText("+$points", item.position, Colors.greenAccent);

      if (item.type == CatchItemType.poop || item.type == CatchItemType.goldenPoop) {
        poopsCaughtConsecutively++;
        if (poopsCaughtConsecutively % 10 == 0) {
          comboMultiplier++;
          addFloatingText("¡Combo x$comboMultiplier!", item.position, Colors.orangeAccent);
        }
        
        // Activar fiebre
        if (poopsCaughtConsecutively > 15 && !isFeverMode) {
          isFeverMode = true;
          feverTimeRemaining = 5.0;
          catchSpeed = 300.0; // Caen más rápido
          addFloatingText("¡FIEBRE!", toilet.position, Colors.amber, size: 24);
        }
      }
      
      // K-Coins por cada cosa atrapada
      if (item.type == CatchItemType.goldenPoop) onAddKcoins(5);
      if (item.type == CatchItemType.poop && Random().nextDouble() < 0.1) onAddKcoins(1);
    }
  }

  void addFloatingText(String text, Vector2 pos, Color color, {double size = 14.0}) {
    add(FloatingTextComponent(text: text, color: color, fontSize: size)..position = pos.clone());
  }
}

// --- COMPONENTES ---

class BackgroundComponent extends PositionComponent with HasGameRef<CacaCatchFlameGame> {
  @override
  void render(Canvas canvas) {
    Color bgColor = const Color(0xFF0D0D0D); // Negro
    if (gameRef.level == 2) bgColor = const Color(0xFF0F172A);
    if (gameRef.level == 3) bgColor = const Color(0xFF1E1B4B);
    if (gameRef.level >= 4) bgColor = const Color(0xFF450A0A);
    
    canvas.drawRect(Rect.fromLTWH(0, 0, gameRef.size.x, gameRef.size.y), Paint()..color = bgColor);

    // Cuadrícula
    final gridPaint = Paint()
      ..color = gameRef.isFeverMode ? Colors.amber.withAlpha(20) : Colors.white.withAlpha(12)
      ..strokeWidth = 0.5;
    for (double i = 0; i < gameRef.size.x; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, gameRef.size.y), gridPaint);
    }
    for (double j = 0; j < gameRef.size.y; j += 40) {
      canvas.drawLine(Offset(0, j), Offset(gameRef.size.x, j), gridPaint);
    }
  }
}

class ToiletPlayer extends PositionComponent with HasGameRef<CacaCatchFlameGame>, CollisionCallbacks {
  bool hasShield;
  ui.Image? cachedToiletImage;

  ToiletPlayer({required this.hasShield}) {
    size = Vector2(60, 60);
    anchor = Anchor.center;
    add(RectangleHitbox(size: Vector2(44, 20), position: Vector2(8, 0))); // Hitbox en la taza
  }

  @override
  Future<void> onLoad() async {
    cachedToiletImage = await SpriteRasterizer.rasterize(60, 60, (canvas) {
      _drawToiletStatic(canvas, const Offset(30, 30));
    });
  }

  @override
  void render(Canvas canvas) {
    final double half = 22; // Radio de la taza
    final center = Offset(size.x / 2, size.y / 2);

    if (hasShield) {
      final shieldPaint = Paint()
        ..color = Colors.blueAccent.withAlpha(70)
        ..style = PaintingStyle.fill;
      final borderPaint = Paint()
        ..color = Colors.blueAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, 34, shieldPaint);
      canvas.drawCircle(center, 34, borderPaint);
    }

    if (gameRef.isSodaFrenzy) {
      final frenzyPaint = Paint()
        ..color = Colors.cyanAccent.withAlpha(70)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 36, frenzyPaint);
    }

    if (gameRef.isFeverMode) {
      final feverPaint = Paint()
        ..color = Colors.amber.withAlpha(90)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, 32, feverPaint);
    }

    if (cachedToiletImage != null) {
      canvas.drawImage(cachedToiletImage!, Offset.zero, Paint());
    } else {
      _drawToiletStatic(canvas, center);
    }
  }

  void _drawToiletStatic(Canvas canvas, Offset center) {
    final double half = 22;

    // 1. Tanque trasero
    final tankRect = Rect.fromLTWH(center.dx - half * 0.7, center.dy - half * 0.8, half * 1.4, half * 0.7);
    final tankPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(tankRect.left, tankRect.top),
        Offset(tankRect.right, tankRect.bottom),
        [Colors.grey[200]!, Colors.grey[400]!],
      );
    canvas.drawRRect(RRect.fromRectAndRadius(tankRect, const Radius.circular(6)), tankPaint);
    
    // Pulsador de descarga
    canvas.drawCircle(Offset(center.dx, center.dy - half * 0.6), 5, Paint()..color = Colors.grey[600]!);
    canvas.drawCircle(Offset(center.dx, center.dy - half * 0.6), 2, Paint()..color = Colors.grey[300]!);

    // 2. Taza
    final bowlPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(center.dx - 10, center.dy + 5),
        half * 1.1,
        [Colors.white, Colors.grey[300]!, Colors.grey[500]!],
      );
    
    final Path bowlPath = Path();
    bowlPath.moveTo(center.dx - half, center.dy - half * 0.1);
    bowlPath.quadraticBezierTo(center.dx - half * 0.9, center.dy + half * 0.8, center.dx - half * 0.3, center.dy + half * 1.1);
    bowlPath.lineTo(center.dx + half * 0.3, center.dy + half * 1.1);
    bowlPath.quadraticBezierTo(center.dx + half * 0.9, center.dy + half * 0.8, center.dx + half, center.dy - half * 0.1);
    bowlPath.quadraticBezierTo(center.dx, center.dy + half * 0.2, center.dx - half, center.dy - half * 0.1);
    canvas.drawPath(bowlPath, bowlPaint);

    // 3. Aro / Asiento superior
    final rimRect = Rect.fromCenter(center: Offset(center.dx, center.dy - half * 0.1), width: half * 2.0, height: half * 0.7);
    final rimPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(rimRect.left, rimRect.top),
        Offset(rimRect.left, rimRect.bottom),
        [Colors.brown[400]!, Colors.brown[700]!],
      );
    canvas.drawOval(rimRect, rimPaint);
    
    // Hueco interior
    final innerRect = Rect.fromCenter(center: Offset(center.dx, center.dy - half * 0.1), width: half * 1.5, height: half * 0.45);
    final innerPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(innerRect.left, innerRect.top),
        Offset(innerRect.left, innerRect.bottom),
        [Colors.lightBlue[900]!, Colors.cyan[900]!],
      );
    canvas.drawOval(innerRect, innerPaint);
    
    // Brillo en el agua
    canvas.drawOval(
      Rect.fromLTWH(center.dx - half * 0.4, center.dy - half * 0.2, half * 0.3, half * 0.1),
      Paint()..color = Colors.white.withAlpha(120),
    );
  }
}

class FallingItem extends PositionComponent with HasGameRef<CacaCatchFlameGame>, CollisionCallbacks {
  final CatchItemType type;
  final double speed;
  final String skin;
  
  double age = 0; // Para animaciones

  FallingItem({required this.type, required this.speed, required this.skin}) {
    size = Vector2(30, 30);
    anchor = Anchor.center;
    add(CircleHitbox(radius: 12, position: Vector2(3, 3)));
  }

  @override
  void update(double dt) {
    super.update(dt);
    age += dt;
    
    // Aplicar gravedad y magnetismo
    double currentSpeed = speed;
    Vector2 dir = Vector2(0, 1);
    
    bool useMagnet = false;
    if (gameRef.isFeverMode && gameRef.hasFeverMagnet) useMagnet = true;
    if (gameRef.hasImprovedMagnet) useMagnet = true;

    if (useMagnet) {
      bool isGood = type == CatchItemType.poop || type == CatchItemType.goldenPoop || type == CatchItemType.paper;
      if (isGood && position.y > 0 && position.y < gameRef.size.y - 40) {
        final toPlayer = gameRef.toilet.position - position;
        if (toPlayer.length < 200) {
          dir = toPlayer.normalized();
          currentSpeed *= 1.5;
        }
      }
    }

    position.add(dir * currentSpeed * dt);

    if (position.y > gameRef.size.y + 40) {
      removeFromParent();
      if (type == CatchItemType.poop || type == CatchItemType.goldenPoop) {
        gameRef.poopsCaughtConsecutively = 0;
        gameRef.comboMultiplier = 1;
      }
    }
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is ToiletPlayer) {
      gameRef.handleItemCaught(this);
    }
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    
    if (type == CatchItemType.bacteria) {
      _drawBacteriaVector(canvas, center, 24);
    } else if (type == CatchItemType.soap) {
      _drawSoapVector(canvas, center, 22);
    } else if (type == CatchItemType.soda) {
      _drawSodaVector(canvas, center, 22);
    } else if (type == CatchItemType.chlorineBomb) {
      _drawBombVector(canvas, center, 24);
    } else {
      String icon = '💩';
      if (type == CatchItemType.paper) icon = '🧻';
      if (type == CatchItemType.goldenPoop) icon = '✨';
      if (type == CatchItemType.poop) icon = skin;

      if (type == CatchItemType.goldenPoop) {
        canvas.drawCircle(center, 16, Paint()..color = Colors.amber.withAlpha(80)..maskFilter = const MaskFilter.blur(BlurStyle.solid, 8));
      }

      final textPainter = TextPainter(
        text: TextSpan(text: icon, style: const TextStyle(fontSize: 26)),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2));
    }
  }

  void _drawBacteriaVector(Canvas canvas, Offset center, double s) {
    final double half = s / 2;
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(center.dx - 3, center.dy - 3), half,
        [Colors.purpleAccent[200]!, Colors.purple[800]!],
      );
    
    final path = Path();
    final int points = 10;
    final double angleStep = (2 * pi) / points;
    
    for (int i = 0; i < points; i++) {
      double angle = i * angleStep;
      double wave = sin(age * 10.0 + i) * 3.0; // Animación basada en dt (age)
      double r = half + (i % 2 == 0 ? 5.0 + wave : -2.0);
      double px = center.dx + cos(angle) * r;
      double py = center.dy + sin(angle) * r;
      if (i == 0) path.moveTo(px, py);
      else path.lineTo(px, py);
    }
    path.close();
    canvas.drawPath(path, paint);
    
    final eyePaint = Paint()..color = Colors.redAccent;
    final pupilPaint = Paint()..color = Colors.white;
    final leftEye = Offset(center.dx - half * 0.3, center.dy - half * 0.1);
    final rightEye = Offset(center.dx + half * 0.3, center.dy - half * 0.1);
    
    canvas.drawCircle(leftEye, 4.5, eyePaint);
    canvas.drawCircle(leftEye - const Offset(1, 1), 1.5, pupilPaint);
    canvas.drawCircle(rightEye, 4.5, eyePaint);
    canvas.drawCircle(rightEye - const Offset(1, 1), 1.5, pupilPaint);
    
    final eyebrow = Paint()..color = Colors.black..strokeWidth = 2.0..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(center.dx - half * 0.5, center.dy - half * 0.4), Offset(center.dx - half * 0.1, center.dy - half * 0.2), eyebrow);
    canvas.drawLine(Offset(center.dx + half * 0.5, center.dy - half * 0.4), Offset(center.dx + half * 0.1, center.dy - half * 0.2), eyebrow);
  }

  void _drawSoapVector(Canvas canvas, Offset center, double s) {
    final soapRect = Rect.fromCenter(center: center, width: s * 1.2, height: s * 0.7);
    final soapPaint = Paint()..shader = ui.Gradient.linear(Offset(soapRect.left, soapRect.top), Offset(soapRect.right, soapRect.bottom), [Colors.lightBlue[300]!, Colors.blue[600]!]);
    canvas.drawRRect(RRect.fromRectAndRadius(soapRect, const Radius.circular(8)), soapPaint);
    final shinePath = Path()..moveTo(soapRect.left + 5, soapRect.top + 3)..lineTo(soapRect.right - 10, soapRect.top + 3)..lineTo(soapRect.right - 20, soapRect.top + 7)..lineTo(soapRect.left + 5, soapRect.top + 7)..close();
    canvas.drawPath(shinePath, Paint()..color = Colors.white.withAlpha(100));
  }

  void _drawSodaVector(Canvas canvas, Offset center, double s) {
    final double half = s / 2;
    final canRect = Rect.fromCenter(center: center, width: s * 0.7, height: s * 1.2);
    final paint = Paint()..shader = ui.Gradient.linear(Offset(center.dx - half, center.dy - half), Offset(center.dx + half, center.dy + half), [Colors.cyanAccent, Colors.teal[600]!]);
    canvas.drawRRect(RRect.fromRectAndRadius(canRect, const Radius.circular(4)), paint);
    final metalPaint = Paint()..color = Colors.grey[400]!;
    canvas.drawOval(Rect.fromCenter(center: Offset(center.dx, canRect.top), width: s * 0.7, height: 4), metalPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(center.dx, canRect.bottom), width: s * 0.7, height: 4), metalPaint);
    final lPath = Path()..moveTo(center.dx + 2, center.dy - 10)..lineTo(center.dx - 6, center.dy + 1)..lineTo(center.dx - 1, center.dy + 1)..lineTo(center.dx - 3, center.dy + 10)..lineTo(center.dx + 5, center.dy - 1)..lineTo(center.dx, center.dy - 1)..close();
    canvas.drawPath(lPath, Paint()..color = Colors.yellowAccent);
  }

  void _drawBombVector(Canvas canvas, Offset center, double s) {
    final double half = s / 2;
    final paint = Paint()..shader = ui.Gradient.radial(Offset(center.dx - 4, center.dy - 4), half * 1.1, [Colors.grey[800]!, Colors.black]);
    canvas.drawCircle(center, half, paint);
    canvas.drawRect(Rect.fromLTWH(center.dx - 3, center.dy - half - 4, 6, 4), Paint()..color = Colors.grey[500]!);
    final wickPath = Path()..moveTo(center.dx, center.dy - half - 4)..quadraticBezierTo(center.dx + 8, center.dy - half - 10, center.dx + 5, center.dy - half - 16);
    canvas.drawPath(wickPath, Paint()..color = Colors.brown[400]!..strokeWidth = 2.0..style = PaintingStyle.stroke);
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
    position.y -= dt * 50; // Sube lentamente
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
