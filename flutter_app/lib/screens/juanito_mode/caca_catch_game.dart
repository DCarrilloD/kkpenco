import 'dart:ui' as ui;
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'in_game_overlay.dart';
import 'shared_game_components.dart';
import '../../models/achievement.dart';
import 'flame_games/sprite_rasterizer.dart';

enum CatchItemType { poop, paper, bacteria, soap, goldenPoop, soda, chlorineBomb }

class CatchItem {
  double x;
  double y;
  final CatchItemType type;
  final String icon;
  final Color color;

  CatchItem({
    required this.x,
    required this.y,
    required this.type,
    required this.icon,
    required this.color,
  });
}

class CacaCatchPainter extends CustomPainter {
  final List<CatchItem> items;
  final double toiletX;
  final List<GameParticle> particles;
  final bool hasSoapShield;
  final bool isSodaFrenzy;
  final bool isFeverMode;
  final double width;
  final double height;
  final List<FloatingText> floatingTexts;
  final int level;

  final ui.Image? cachedToiletImage;
  final ui.Image? cachedBacteriaImage;
  final ui.Image? cachedSoapImage;
  final ui.Image? cachedSodaImage;
  final ui.Image? cachedBombImage;
  final ui.Image? cachedPoopImage;
  final ui.Image? cachedGoldenPoopImage;

  final Color? toiletFlashColor;
  final double toiletFlashTimer;

  final int soapShieldTicksRemaining;
  final int sodaFrenzyTicksRemaining;
  final int feverTicksRemaining;

  CacaCatchPainter({
    required this.items,
    required this.toiletX,
    required this.particles,
    required this.hasSoapShield,
    required this.isSodaFrenzy,
    required this.isFeverMode,
    required this.width,
    required this.height,
    required this.floatingTexts,
    required this.level,
    required this.cachedToiletImage,
    required this.cachedBacteriaImage,
    required this.cachedSoapImage,
    required this.cachedSodaImage,
    required this.cachedBombImage,
    required this.cachedPoopImage,
    required this.cachedGoldenPoopImage,
    required this.toiletFlashColor,
    required this.toiletFlashTimer,
    required this.soapShieldTicksRemaining,
    required this.sodaFrenzyTicksRemaining,
    required this.feverTicksRemaining,
  });

  static void drawToiletVectorStatic(Canvas canvas, Offset center, double size) {
    final double half = size / 2;
    
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

    // 2. Taza (cuerpo elíptico de cerámica)
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

    // 3. Aro / Asiento superior (abierto / elipse)
    final rimRect = Rect.fromCenter(center: Offset(center.dx, center.dy - half * 0.1), width: half * 2.0, height: half * 0.7);
    final rimPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(rimRect.left, rimRect.top),
        Offset(rimRect.left, rimRect.bottom),
        [Colors.brown[400]!, Colors.brown[700]!],
      );
    canvas.drawOval(rimRect, rimPaint);
    
    // Hueco interior oscuro de la taza
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

  static void drawBacteriaVectorStatic(Canvas canvas, Offset center, double size) {
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
    
    for (int i = 0; i < points; i++) {
      double angle = i * angleStep;
      double r = half + (i % 2 == 0 ? 3.0 : -1.5);
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
    
    final leftEyeCenter = Offset(center.dx - half * 0.3, center.dy - half * 0.1);
    final rightEyeCenter = Offset(center.dx + half * 0.3, center.dy - half * 0.1);
    
    canvas.drawCircle(leftEyeCenter, 4.5, eyePaint);
    canvas.drawCircle(leftEyeCenter - const Offset(1, 1), 1.5, pupilPaint);
    
    canvas.drawCircle(rightEyeCenter, 4.5, eyePaint);
    canvas.drawCircle(rightEyeCenter - const Offset(1, 1), 1.5, pupilPaint);
    
    final eyebrowPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    
    canvas.drawLine(Offset(center.dx - half * 0.5, center.dy - half * 0.4), Offset(center.dx - half * 0.1, center.dy - half * 0.2), eyebrowPaint);
    canvas.drawLine(Offset(center.dx + half * 0.5, center.dy - half * 0.4), Offset(center.dx + half * 0.1, center.dy - half * 0.2), eyebrowPaint);
  }

  static void drawSoapVectorStatic(Canvas canvas, Offset center, double size) {
    final soapRect = Rect.fromCenter(center: center, width: size * 1.2, height: size * 0.7);
    final soapPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(soapRect.left, soapRect.top),
        Offset(soapRect.right, soapRect.bottom),
        [Colors.lightBlue[300]!, Colors.blue[600]!],
      );
    canvas.drawRRect(RRect.fromRectAndRadius(soapRect, const Radius.circular(8)), soapPaint);
    
    final shinePaint = Paint()..color = Colors.white.withAlpha(100);
    final shinePath = Path()
      ..moveTo(soapRect.left + 5, soapRect.top + 3)
      ..lineTo(soapRect.right - 10, soapRect.top + 3)
      ..lineTo(soapRect.right - 20, soapRect.top + 7)
      ..lineTo(soapRect.left + 5, soapRect.top + 7)
      ..close();
    canvas.drawPath(shinePath, shinePaint);
    
    final bubblePaint = Paint()
      ..color = Colors.white.withAlpha(160)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center + const Offset(-18, -12), 4, bubblePaint);
    canvas.drawCircle(center + const Offset(16, 10), 3, bubblePaint);
  }

  static void drawSodaVectorStatic(Canvas canvas, Offset center, double size) {
    final double half = size / 2;
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(center.dx - half, center.dy - half),
        Offset(center.dx + half, center.dy + half),
        [Colors.cyanAccent, Colors.teal[600]!],
      );
    
    final canRect = Rect.fromCenter(center: center, width: size * 0.7, height: size * 1.2);
    canvas.drawRRect(RRect.fromRectAndRadius(canRect, const Radius.circular(4)), paint);
    
    final metalPaint = Paint()..color = Colors.grey[400]!;
    canvas.drawOval(Rect.fromCenter(center: Offset(center.dx, canRect.top), width: size * 0.7, height: 4), metalPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(center.dx, canRect.bottom), width: size * 0.7, height: 4), metalPaint);
    
    final lightningPaint = Paint()..color = Colors.yellowAccent;
    final lPath = Path()
      ..moveTo(center.dx + 2, center.dy - 10)
      ..lineTo(center.dx - 6, center.dy + 1)
      ..lineTo(center.dx - 1, center.dy + 1)
      ..lineTo(center.dx - 3, center.dy + 10)
      ..lineTo(center.dx + 5, center.dy - 1)
      ..lineTo(center.dx, center.dy - 1)
      ..close();
    canvas.drawPath(lPath, lightningPaint);
  }

  static void drawBombVectorStatic(Canvas canvas, Offset center, double size) {
    final double half = size / 2;
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(center.dx - 4, center.dy - 4),
        half * 1.1,
        [Colors.grey[800]!, Colors.black],
      );
    
    canvas.drawCircle(center, half, paint);
    canvas.drawRect(Rect.fromLTWH(center.dx - 3, center.dy - half - 4, 6, 4), Paint()..color = Colors.grey[500]!);
    
    final wickPaint = Paint()
      ..color = Colors.brown[400]!
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    final wickPath = Path()
      ..moveTo(center.dx, center.dy - half - 4)
      ..quadraticBezierTo(center.dx + 8, center.dy - half - 10, center.dx + 5, center.dy - half - 16);
    canvas.drawPath(wickPath, wickPaint);
    
    final sparkPaint = Paint()..color = Colors.amberAccent;
    final double sparkX = center.dx + 5;
    final double sparkY = center.dy - half - 16;
    canvas.drawCircle(Offset(sparkX - 2, sparkY - 2), 1.5, sparkPaint);
    canvas.drawCircle(Offset(sparkX + 3, sparkY + 1), 1.5, sparkPaint);
    canvas.drawCircle(Offset(sparkX - 1, sparkY + 4), 1.5, sparkPaint);
    canvas.drawCircle(Offset(sparkX + 4, sparkY - 3), 1.5, sparkPaint);
  }

  @override
  void paint(Canvas canvas, ui.Size size) {
    // 1. Dibujar fondo estético por nivel
    Color bgColor;
    if (level == 1) {
      bgColor = const Color(0xFF0D0D0D);
    } else if (level == 2) {
      bgColor = const Color(0xFF0F172A);
    } else if (level == 3) {
      bgColor = const Color(0xFF1E1B4B);
    } else {
      bgColor = const Color(0xFF450A0A);
    }
    
    final bgPaint = Paint()..color = bgColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), bgPaint);

    // Dibujar fondo de cuadrícula
    final gridPaint = Paint()
      ..color = isFeverMode ? Colors.amber.withAlpha(20) : Colors.white.withAlpha(12)
      ..strokeWidth = 0.5;
    for (double i = 0; i < width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, height), gridPaint);
    }
    for (double j = 0; j < height; j += 40) {
      canvas.drawLine(Offset(0, j), Offset(width, j), gridPaint);
    }

    if (isFeverMode) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: '¡FIEBRE!',
          style: TextStyle(
            color: Colors.amber.withAlpha(40),
            fontSize: 42,
            fontWeight: FontWeight.bold,
            letterSpacing: 8,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset((width - textPainter.width) / 2, height * 0.35));
    }

    // Dibujar items
    for (var item in items) {
      final itemCenter = Offset(item.x * width, item.y * height);
      final isSpecial = item.type == CatchItemType.goldenPoop || item.type == CatchItemType.soap || item.type == CatchItemType.soda || item.type == CatchItemType.chlorineBomb;
      
      if (isSpecial) {
        final glowPaint = Paint()
          ..color = item.color.withAlpha(80)
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 8);
        canvas.drawCircle(itemCenter, 16, glowPaint);
      }

      // Renderizar dibujo vectorial cacheado (rasterizado) o emoji según el caso
      if (item.type == CatchItemType.bacteria && cachedBacteriaImage != null) {
        canvas.drawImage(cachedBacteriaImage!, Offset(itemCenter.dx - 24, itemCenter.dy - 24), Paint());
      } else if (item.type == CatchItemType.soap && cachedSoapImage != null) {
        canvas.drawImage(cachedSoapImage!, Offset(itemCenter.dx - 22, itemCenter.dy - 22), Paint());
      } else if (item.type == CatchItemType.soda && cachedSodaImage != null) {
        canvas.drawImage(cachedSodaImage!, Offset(itemCenter.dx - 22, itemCenter.dy - 22), Paint());
      } else if (item.type == CatchItemType.chlorineBomb && cachedBombImage != null) {
        canvas.drawImage(cachedBombImage!, Offset(itemCenter.dx - 24, itemCenter.dy - 24), Paint());
      } else if (item.type == CatchItemType.poop && cachedPoopImage != null) {
        canvas.drawImage(cachedPoopImage!, Offset(itemCenter.dx - 26, itemCenter.dy - 26), Paint());
      } else if (item.type == CatchItemType.goldenPoop && cachedGoldenPoopImage != null) {
        canvas.drawImage(cachedGoldenPoopImage!, Offset(itemCenter.dx - 26, itemCenter.dy - 26), Paint());
      } else {
        // Fallback vectorial dinámico o emoji
        if (item.type == CatchItemType.bacteria) {
          drawBacteriaVectorStatic(canvas, itemCenter, 24);
        } else if (item.type == CatchItemType.soap) {
          drawSoapVectorStatic(canvas, itemCenter, 22);
        } else if (item.type == CatchItemType.soda) {
          drawSodaVectorStatic(canvas, itemCenter, 22);
        } else if (item.type == CatchItemType.chlorineBomb) {
          drawBombVectorStatic(canvas, itemCenter, 24);
        } else {
          final textPainter = TextPainter(
            text: TextSpan(text: item.icon, style: const TextStyle(fontSize: 26)),
            textDirection: TextDirection.ltr,
          );
          textPainter.layout();
          textPainter.paint(canvas, Offset(itemCenter.dx - textPainter.width / 2, itemCenter.dy - textPainter.height / 2));
        }
      }
    }

    // Dibujar inodoro en la parte inferior
    final toiletY = height - 50.0;
    final toiletRealX = toiletX * width;
    final toiletCenter = Offset(toiletRealX, toiletY + 10);
    
    if (hasSoapShield) {
      final shieldPaint = Paint()
        ..color = Colors.blueAccent.withAlpha(70)
        ..style = PaintingStyle.fill;
      final borderPaint = Paint()
        ..color = Colors.blueAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(Offset(toiletRealX, toiletY + 12), 34, shieldPaint);
      canvas.drawCircle(Offset(toiletRealX, toiletY + 12), 34, borderPaint);
    }

    if (isSodaFrenzy) {
      final frenzyPaint = Paint()
        ..color = Colors.cyanAccent.withAlpha(70)
        ..style = PaintingStyle.fill;
      final frenzyBorder = Paint()
        ..color = Colors.cyanAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(Offset(toiletRealX, toiletY + 12), 36, frenzyPaint);
      canvas.drawCircle(Offset(toiletRealX, toiletY + 12), 36, frenzyBorder);
    }

    if (isFeverMode) {
      final feverPaint = Paint()
        ..color = Colors.amber.withAlpha(90)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(toiletRealX, toiletY + 12), 32, feverPaint);
    }

    // HUD Temporizadores circulares sobre la taza
    if (soapShieldTicksRemaining > 0) {
      final progressPaint = Paint()
        ..color = Colors.blueAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      final rect = Rect.fromCircle(center: toiletCenter, radius: 34);
      double sweepAngle = (soapShieldTicksRemaining / 130.0).clamp(0.0, 1.0) * 2 * pi;
      canvas.drawArc(rect, -pi / 2, sweepAngle, false, progressPaint);
    }
    if (sodaFrenzyTicksRemaining > 0) {
      final progressPaint = Paint()
        ..color = Colors.cyanAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      final rect = Rect.fromCircle(center: toiletCenter, radius: 38);
      double sweepAngle = (sodaFrenzyTicksRemaining / 200.0).clamp(0.0, 1.0) * 2 * pi;
      canvas.drawArc(rect, -pi / 2, sweepAngle, false, progressPaint);
    }
    if (feverTicksRemaining > 0) {
      final progressPaint = Paint()
        ..color = Colors.amberAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      final rect = Rect.fromCircle(center: toiletCenter, radius: 30);
      double sweepAngle = (feverTicksRemaining / 130.0).clamp(0.0, 1.0) * 2 * pi;
      canvas.drawArc(rect, -pi / 2, sweepAngle, false, progressPaint);
    }

    // Taza de inodoro vectorial (o cacheada)
    if (cachedToiletImage != null) {
      final toiletPaint = Paint();
      if (toiletFlashTimer > 0 && toiletFlashColor != null) {
        toiletPaint.colorFilter = ColorFilter.mode(toiletFlashColor!, BlendMode.srcATop);
      }
      canvas.drawImage(cachedToiletImage!, Offset(toiletRealX - 44, toiletY + 10 - 44), toiletPaint);
    } else {
      drawToiletVectorStatic(canvas, Offset(toiletRealX, toiletY + 10), 44);
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
            fontSize: 18,
            color: Colors.white.withAlpha((particle.opacity * 255).toInt()),
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      pPainter.layout();
      pPainter.paint(canvas, Offset(-pPainter.width / 2, -pPainter.height / 2));
      canvas.restore();
    }

    // Dibujar textos flotantes animados (con rotación y escala de rebote)
    for (var ft in floatingTexts) {
      canvas.save();
      canvas.translate(ft.x, ft.y);
      
      // Inclinación suave basada en el texto para no ser rígido
      double angle = ((ft.text.hashCode % 10) - 5) * 0.04;
      canvas.rotate(angle);
      
      // Escala de pop inicial
      double scale = ft.opacity > 0.8 ? 1.0 + (ft.opacity - 0.8) * 1.5 : 1.0;
      canvas.scale(scale);

      final textPainter = TextPainter(
        text: TextSpan(
          text: ft.text,
          style: TextStyle(
            color: ft.color.withAlpha((ft.opacity * 255).toInt()),
            fontSize: ft.fontSize,
            fontWeight: FontWeight.w900,
            shadows: const [
              Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1)),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// --- FLAPPY POOP ---
class FlappyPipe {
  double x;
  final double gapY;
  final double gapHeight;
  bool passed = false;
  bool hasStar;
  bool starCollected;

  FlappyPipe({
    required this.x,
    required this.gapY,
    required this.gapHeight,
    this.hasStar = false,
    this.starCollected = false,
  });
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
  });

  @override
  void paint(Canvas canvas, Size size) {
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
      ..color = Colors.white10
      ..strokeWidth = 0.5;
    for (double i = 0; i < width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, height), gridPaint);
    }
    for (double j = 0; j < height; j += 40) {
      canvas.drawLine(Offset(0, j), Offset(width, j), gridPaint);
    }

    // Dibujar tuberías
    final pipePaint = Paint()
      ..color = Colors.green[800]!
      ..style = PaintingStyle.fill;
    final rimPaint = Paint()
      ..color = Colors.green[600]!
      ..style = PaintingStyle.fill;
    final shadowPaint = Paint()
      ..color = Colors.black38
      ..style = PaintingStyle.fill;

    for (var pipe in pipes) {
      // Sombra proyectada
      canvas.drawRect(Rect.fromLTWH(pipe.x + 4, 0, 50, pipe.gapY), shadowPaint);
      canvas.drawRect(Rect.fromLTWH(pipe.x + 4, pipe.gapY + pipe.gapHeight, 50, height - (pipe.gapY + pipe.gapHeight)), shadowPaint);

      // Tubería superior
      canvas.drawRect(Rect.fromLTWH(pipe.x, 0, 50, pipe.gapY), pipePaint);
      canvas.drawRect(Rect.fromLTWH(pipe.x - 3, pipe.gapY - 18, 56, 18), rimPaint);

      // Tubería inferior
      canvas.drawRect(Rect.fromLTWH(pipe.x, pipe.gapY + pipe.gapHeight, 50, height - (pipe.gapY + pipe.gapHeight)), pipePaint);
      canvas.drawRect(Rect.fromLTWH(pipe.x - 3, pipe.gapY + pipe.gapHeight, 56, 18), rimPaint);

      // Dibujar estrella si está presente
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

    // Dibujar línea de High Score
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

    final textPainter = TextPainter(
      text: TextSpan(text: equippedSkin, style: const TextStyle(fontSize: 28)),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
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
enum PlatformType { normal, moving, fragile, superSpring }
enum ItemType { none, spring, jetpack, balloon }



class CacaCatchGame extends StatefulWidget {
  final String equippedSkin;
  final bool hasImprovedMagnet;
  final bool hasInitialSoapShield;
  final bool hasExtraLife;
  final bool hasFeverMagnet;
  final Function(int) onGameOver;
  final Function(int) onAddKcoins;
  final Function() onUnlockAchievement;
  final int highScore;
  final Function(int) onSaveHighScore;
  final AchievementCategory? activeBuffCategory;

  const CacaCatchGame({
    super.key,
    required this.equippedSkin,
    required this.hasImprovedMagnet,
    required this.hasInitialSoapShield,
    required this.hasExtraLife,
    required this.hasFeverMagnet,
    required this.onGameOver,
    required this.onAddKcoins,
    required this.onUnlockAchievement,
    required this.highScore,
    required this.onSaveHighScore,
    this.activeBuffCategory,
  });

  @override
  State<CacaCatchGame> createState() => _CacaCatchGameState();
}

class _CacaCatchGameState extends State<CacaCatchGame> with SingleTickerProviderStateMixin {
  double _shakeX = 0.0;
  double _shakeY = 0.0;
  Color? _flashColor;

  void _spawnParticles(double x, double y, String emoji, int count, {double speed = 1.0}) {
    final r = Random();
    for (int i = 0; i < count; i++) {
      _particles.add(GameParticle(
        x: x,
        y: y,
        vx: (r.nextDouble() - 0.5) * 4 * speed,
        vy: (r.nextDouble() - 0.5) * 4 * speed,
        lifeTime: 30 + r.nextInt(20),
        emoji: emoji,
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
  // Game variables
  int _level = 1;
  double _toiletX = 0.5;
  final List<CatchItem> _catchItems = [];
  Ticker? _ticker;
  double _lastElapsedMs = 0.0;
  double _catchSpawnProb = 0.05;
  double _catchSpeed = 0.015;
  
  bool _isMagnetActive = false;
  bool _isFeverMode = false;
  int _feverTicksRemaining = 0;
  bool _hasSoapShield = false;
  int _soapShieldTicksRemaining = 0;
  bool _isSodaFrenzy = false;
  int _sodaFrenzyTicksRemaining = 0;
  bool _isPausedLocal = false;
  bool _hasExtraLifeLocal = false;
  bool _hasInitialSoapShieldLocal = false;
  bool _hasFeverMagnetLocal = false;
  double _gameWidth = 400;
  double _gameHeight = 800;
  bool _isCacaCatchGameOver = false;
  
  int _score = 0;
  int _lives = 3;
  int _comboMultiplier = 1;
  int _poopsCaughtConsecutively = 0;
  
  final List<FloatingText> _floatingTexts = [];
  final List<GameParticle> _particles = [];
  
  // Audio flags (stubbed for now or we can ignore them if they don't matter inside)
  bool _isSoundEnabled = true;

  // Sprite cache & toilet flash states
  ui.Image? _cachedToiletImage;
  ui.Image? _cachedBacteriaImage;
  ui.Image? _cachedSoapImage;
  ui.Image? _cachedSodaImage;
  ui.Image? _cachedBombImage;
  ui.Image? _cachedPoopImage;
  ui.Image? _cachedGoldenPoopImage;
  Color? _toiletFlashColor;
  double _toiletFlashTimer = 0.0;

  @override
  void initState() {
    super.initState();
    _hasExtraLifeLocal = widget.hasExtraLife;
    _hasInitialSoapShieldLocal = widget.hasInitialSoapShield;
    _hasFeverMagnetLocal = widget.hasFeverMagnet;
    _rasterizeAssets();
    _startCacaCatch();
  }

  Future<void> _rasterizeAssets() async {
    _cachedToiletImage = await SpriteRasterizer.rasterize(88, 88, (canvas) {
      CacaCatchPainter.drawToiletVectorStatic(canvas, const Offset(44, 44), 44);
    });
    _cachedBacteriaImage = await SpriteRasterizer.rasterize(48, 48, (canvas) {
      CacaCatchPainter.drawBacteriaVectorStatic(canvas, const Offset(24, 24), 24);
    });
    _cachedSoapImage = await SpriteRasterizer.rasterize(44, 44, (canvas) {
      CacaCatchPainter.drawSoapVectorStatic(canvas, const Offset(22, 22), 22);
    });
    _cachedSodaImage = await SpriteRasterizer.rasterize(44, 44, (canvas) {
      CacaCatchPainter.drawSodaVectorStatic(canvas, const Offset(22, 22), 22);
    });
    _cachedBombImage = await SpriteRasterizer.rasterize(48, 48, (canvas) {
      CacaCatchPainter.drawBombVectorStatic(canvas, const Offset(24, 24), 24);
    });
    _cachedPoopImage = await SpriteRasterizer.rasterize(52, 52, (canvas) {
      final textPainter = TextPainter(
        text: TextSpan(text: widget.equippedSkin, style: const TextStyle(fontSize: 26)),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(26 - textPainter.width / 2, 26 - textPainter.height / 2));
    });
    _cachedGoldenPoopImage = await SpriteRasterizer.rasterize(52, 52, (canvas) {
      final textPainter = TextPainter(
        text: const TextSpan(text: '⭐', style: TextStyle(fontSize: 26)),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(26 - textPainter.width / 2, 26 - textPainter.height / 2));
    });
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker?.stop();
    _ticker?.dispose();
    super.dispose();
  }
  
  @override
  void didUpdateWidget(CacaCatchGame oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Handle pause/resume if needed
  }

  bool randPercent(double p) => Random().nextDouble() < p;

  // ==========================================
  // --- MINIJUEGO 1: CACA CATCH (ATRACA) ---
  // ==========================================
  void _startCacaCatch() {
    _stopCacaCatch();
    setState(() {
      _score = 0;
      _level = 1;
      _lives = _hasExtraLifeLocal ? 4 : 3;
      if (widget.activeBuffCategory == AchievementCategory.games) _lives++;
      _hasExtraLifeLocal = false; // consumido
      
      _catchItems.clear();
      _toiletX = 0.5;
      _catchSpawnProb = 0.05;
      _catchSpeed = 0.015;
      
      _isFeverMode = false;
      _feverTicksRemaining = 0;
      _isSodaFrenzy = false;
      _sodaFrenzyTicksRemaining = 0;
      _hasSoapShield = _hasInitialSoapShieldLocal;
      _soapShieldTicksRemaining = _hasInitialSoapShieldLocal ? 150 : 0;
      _hasInitialSoapShieldLocal = false; // consumido
      
      _isMagnetActive = _hasFeverMagnetLocal;
      _hasFeverMagnetLocal = false; // consumido
      
      _particles.clear();
      
      _floatingTexts.clear();
      _comboMultiplier = 1;
      _poopsCaughtConsecutively = 0;
      
      _isCacaCatchGameOver = false;
    });

    if (true) {
      widget.onUnlockAchievement();
    }

    _lastElapsedMs = 0.0;
    _ticker = createTicker((elapsed) {
      final currentMs = elapsed.inMilliseconds.toDouble();
      double dt = _lastElapsedMs == 0.0 ? 0.016 : (currentMs - _lastElapsedMs) / 1000.0;
      if (dt > 0.1) dt = 0.016; // prevenir saltos masivos al pausar o reanudar
      _lastElapsedMs = currentMs;
      _updateCacaCatchStep(dt);
    });
    _ticker!.start();
  }

  void _stopCacaCatch() {
    _ticker?.stop();
    _ticker?.dispose();
    _ticker = null;
  }

  void _updateCacaCatchStep(double dt) {
    if (_isPausedLocal || _isCacaCatchGameOver) return;
    if (_gameWidth < 100 || _gameHeight < 100) return;

    // Actualizar flash de taza
    if (_toiletFlashTimer > 0) {
      _toiletFlashTimer -= dt;
      if (_toiletFlashTimer <= 0) _toiletFlashColor = null;
    }

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

    final rand = Random();

    // Lógica del imán de caca
    if (_isMagnetActive || _isSodaFrenzy) {
      for (var item in _catchItems) {
        if (item.type == CatchItemType.poop || item.type == CatchItemType.goldenPoop || item.type == CatchItemType.paper || item.type == CatchItemType.soda) {
          double attractionSpeed = _isSodaFrenzy ? 0.075 : (widget.hasImprovedMagnet ? 0.065 : 0.045);
          item.x += (_toiletX - item.x) * attractionSpeed * dt * 33.3; // atracción magnética
        }
      }
    }

    // Lógica de la Soda Frenesí
    if (_isSodaFrenzy) {
      _sodaFrenzyTicksRemaining--;
      if (_sodaFrenzyTicksRemaining <= 0) {
        _isSodaFrenzy = false;
      }
      if (_sodaFrenzyTicksRemaining % 6 == 0) {
        _triggerFlash(Colors.cyanAccent.withAlpha(20), 4);
      }
    }

    // Lógica del modo fiebre
    if (_isFeverMode) {
      _feverTicksRemaining--;
      if (_feverTicksRemaining <= 0) {
        _isFeverMode = false;
      }
      if (_feverTicksRemaining % 8 == 0) {
        _triggerFlash(Colors.amber.withAlpha(25), 5);
      }
    }

    // Lógica del escudo de jabón
    if (_hasSoapShield) {
      _soapShieldTicksRemaining--;
      if (_soapShieldTicksRemaining <= 0) {
        _hasSoapShield = false;
      }
    }

    // Spawn items
    double spawnChance = _isFeverMode ? 0.12 : _catchSpawnProb;
    if (rand.nextDouble() < spawnChance) {
      CatchItemType type;
      String icon;
      Color color;

      if (_isFeverMode) {
        // En modo fiebre caen cacas normales y papel a gran velocidad (sin estrellas para evitar fiebre infinita)
        if (rand.nextDouble() < 0.6) {
          type = CatchItemType.poop;
          icon = widget.equippedSkin;
          color = Colors.brown;
        } else {
          type = CatchItemType.paper;
          icon = '🧻';
          color = Colors.white;
        }
      } else {
        final rVal = rand.nextDouble();
        final bool isCalendarBuff = widget.activeBuffCategory == AchievementCategory.calendar;
        final double paperThreshold = isCalendarBuff ? 0.70 : 0.65;
        final double starThreshold = isCalendarBuff ? 0.90 : 0.95;

        if (rVal < 0.50) {
          type = CatchItemType.poop;
          icon = widget.equippedSkin;
          color = Colors.brown;
        } else if (rVal < paperThreshold) {
          type = CatchItemType.paper;
          icon = '🧻';
          color = Colors.white;
        } else if (rVal < 0.82) {
          type = CatchItemType.bacteria;
          icon = '👾';
          color = Colors.purpleAccent;
        } else if (rVal < 0.88) {
          type = CatchItemType.soap;
          icon = '🧼';
          color = Colors.blueAccent;
        } else if (rVal < 0.92) {
          type = CatchItemType.soda;
          icon = '⚡';
          color = Colors.cyanAccent;
        } else if (rVal < starThreshold) {
          type = CatchItemType.chlorineBomb;
          icon = '💣';
          color = Colors.redAccent;
        } else {
          type = CatchItemType.goldenPoop;
          icon = '⭐';
          color = Colors.amber;
        }
      }

      _catchItems.add(CatchItem(
        x: rand.nextDouble() * 0.9 + 0.05,
        y: 0.0,
        type: type,
        icon: icon,
        color: color,
      ));
    }

    // Calcular nivel y disparar animación si sube
    int newLevel = 1;
    if (_score > 65) {
      newLevel = 3;
    } else if (_score > 30) {
      newLevel = 2;
    }
    if (_score > 100) {
      newLevel = 4;
    }
    if (newLevel != _level) {
      _level = newLevel;
      _triggerFlash(Colors.white.withAlpha(150), 10);
      _triggerShake(8.0, 15);
      _spawnFloatingText(_gameWidth / 2, _gameHeight / 2, '¡NIVEL $_level! 🚀', Colors.amberAccent, fontSize: 32.0);
    }

    // Mover y comprobar colisiones
    double currentSpeed = _isFeverMode ? _catchSpeed * 1.3 : _catchSpeed;
    if (widget.activeBuffCategory == AchievementCategory.locations) {
      currentSpeed *= 0.9;
    }
    for (int i = _catchItems.length - 1; i >= 0; i--) {
      final item = _catchItems[i];
      item.y += currentSpeed * dt * 33.3;

      if (item.type == CatchItemType.goldenPoop && rand.nextDouble() < 0.15) {
        _spawnParticles(item.x * _gameWidth, item.y * _gameHeight, '✨', 1, speed: 0.3);
      } else if (item.type == CatchItemType.soda && rand.nextDouble() < 0.15) {
        _spawnParticles(item.x * _gameWidth, item.y * _gameHeight, '⚡', 1, speed: 0.3);
      } else if (item.type == CatchItemType.soap && rand.nextDouble() < 0.15) {
        _spawnParticles(item.x * _gameWidth, item.y * _gameHeight, '🫧', 1, speed: 0.3);
      }

      if (item.type == CatchItemType.bacteria && _level >= 2) {
        final double timeSec = DateTime.now().millisecondsSinceEpoch / 1000.0;
        double speedFactor = _level == 2 ? 1.5 : 2.5;
        item.x += sin(timeSec * 6.0 + item.y * 10) * 0.005 * speedFactor * dt * 33.3;
        item.x = item.x.clamp(0.08, 0.92);
      }

      // Colisión (píxeles reales basados en la altura del inodoro)
      final itemYPx = item.y * _gameHeight;
      final toiletYPx = _gameHeight - 50.0;

      // Ajustamos la colisión a la boca de la taza (alrededor de toiletYPx - 8.0)
      if ((itemYPx - (toiletYPx - 8.0)).abs() < 14.0) {
        final diff = (item.x * _gameWidth - _toiletX * _gameWidth).abs();
        if (diff < 32.0) {
          _handleCacaCatchHit(item);
          _catchItems.removeAt(i);
          continue;
        }
      }

      // Caída al vacío (suelo)
      if (item.y >= 1.0) {
        if (!_isFeverMode) {
          if (item.type == CatchItemType.poop || item.type == CatchItemType.goldenPoop) {
            _triggerFlash(Colors.red.withAlpha(40), 5);
            HapticFeedback.vibrate();
            _lives--;
            
            // Feedback de vidas y combos rotos
            _spawnFloatingText(item.x * _gameWidth, _gameHeight - 20, '💔 -1 Vida', Colors.redAccent, fontSize: 14);
            if (_comboMultiplier > 1) {
              _spawnFloatingText(item.x * _gameWidth, _gameHeight - 40, '¡COMBO ROTO! ❌', Colors.redAccent, fontSize: 13);
            }
            _comboMultiplier = 1;
            _poopsCaughtConsecutively = 0;
            
            if (_lives <= 0) {
              _isCacaCatchGameOver = true;
              _stopCacaCatch();
            }
          }
        }
        _catchItems.removeAt(i);
      }
    }

    // Dificultad progresiva (solo fuera de modo fiebre)
    if (!_isFeverMode && _score > 0 && _score % 10 == 0) {
      _catchSpeed = 0.015 + (_score ~/ 10) * 0.0015;
      _catchSpawnProb = 0.05 + (_score ~/ 10) * 0.003;
    }

    setState(() {});
  }

  void _handleCacaCatchHit(CatchItem item) {
    final px = item.x * _gameWidth;
    final py = item.y * _gameHeight;

    // Configurar Hit Flash en inodoro
    _toiletFlashTimer = 0.08;
    if (item.type == CatchItemType.poop) {
      _toiletFlashColor = Colors.brown[300];
    } else if (item.type == CatchItemType.paper) {
      _toiletFlashColor = Colors.white;
    } else if (item.type == CatchItemType.soap) {
      _toiletFlashColor = Colors.blueAccent;
    } else if (item.type == CatchItemType.goldenPoop) {
      _toiletFlashColor = Colors.amberAccent;
    } else if (item.type == CatchItemType.soda) {
      _toiletFlashColor = Colors.cyanAccent;
    } else if (item.type == CatchItemType.chlorineBomb) {
      _toiletFlashColor = Colors.redAccent;
    } else if (item.type == CatchItemType.bacteria) {
      _toiletFlashColor = Colors.purpleAccent;
    }

    if (item.type == CatchItemType.poop) {
      HapticFeedback.lightImpact();
      _poopsCaughtConsecutively++;
      if (_poopsCaughtConsecutively >= 5) {
        if (_comboMultiplier < 5) {
          _comboMultiplier++;
          _spawnFloatingText(px, py, '¡COMBO x$_comboMultiplier! 🔥', Colors.amberAccent, fontSize: 18);
        }
        _poopsCaughtConsecutively = 0;
      }
      
      final pointsGained = 1 * _comboMultiplier * (_isSodaFrenzy ? 2 : 1);
      _score += pointsGained;
      _spawnFloatingText(px, py, '+$pointsGained', _isSodaFrenzy ? Colors.cyanAccent : Colors.brown[300]!);
      widget.onSaveHighScore(_score);
      _spawnParticles(px, py, _isSodaFrenzy ? '⚡' : '💦', 5);

      
      if ("" != null && _score >= 50) {
        widget.onUnlockAchievement();
      }
    } else if (item.type == CatchItemType.paper) {
      HapticFeedback.mediumImpact();
      final pointsGained = 3 * _comboMultiplier * (_isSodaFrenzy ? 2 : 1);
      _score += pointsGained;
      _spawnFloatingText(px, py, '+$pointsGained', Colors.white);
      widget.onSaveHighScore(_score);
      _spawnParticles(px, py, '✨', 6);
    } else if (item.type == CatchItemType.soap) {
      HapticFeedback.mediumImpact();
      if (_lives < 3) {
        _lives++;
        _spawnFloatingText(px, py, '+1 Vida ❤️', Colors.redAccent);
      } else {
        final pointsGained = 5 * _comboMultiplier * (_isSodaFrenzy ? 2 : 1);
        _score += pointsGained;
        _spawnFloatingText(px, py, '+$pointsGained', Colors.blueAccent);
        widget.onSaveHighScore(_score);
      }
      _hasSoapShield = true;
      _soapShieldTicksRemaining = 130; // ~4 segundos
      _triggerFlash(Colors.blueAccent.withAlpha(60), 8);
      _spawnParticles(px, py, '🫧', 8);
    } else if (item.type == CatchItemType.goldenPoop) {
      HapticFeedback.heavyImpact();
      final pointsGained = 15 * _comboMultiplier * (_isSodaFrenzy ? 2 : 1);
      _score += pointsGained;
      _spawnFloatingText(px, py, '+$pointsGained ✨', Colors.amberAccent, fontSize: 20);
      widget.onSaveHighScore(_score);
      _isFeverMode = true;
      _feverTicksRemaining = 130; // ~4 segundos
      _triggerFlash(Colors.amber.withAlpha(120), 12);
      _triggerShake(6.0, 12);
      _spawnParticles(px, py, '⭐', 15);
    } else if (item.type == CatchItemType.soda) {
      HapticFeedback.heavyImpact();
      _isSodaFrenzy = true;
      _sodaFrenzyTicksRemaining = 200; // ~6 segundos
      _triggerFlash(Colors.cyanAccent.withAlpha(100), 10);
      _triggerShake(4.0, 10);
      _spawnParticles(px, py, '⚡', 12);
      _spawnFloatingText(px, py, '¡SODA FRENESÍ! ⚡', Colors.cyanAccent, fontSize: 18);
    } else if (item.type == CatchItemType.chlorineBomb) {
      HapticFeedback.heavyImpact();
      _triggerFlash(Colors.white.withAlpha(120), 12);
      _triggerShake(8.0, 15);
      _spawnParticles(px, py, '💥', 15);
      
      // Eliminar bacterias
      int bacteriaCount = 0;
      for (var catchItem in _catchItems) {
        if (catchItem.type == CatchItemType.bacteria) {
          bacteriaCount++;
          _spawnParticles(catchItem.x * _gameWidth, catchItem.y * _gameHeight, '🫧', 5);
        }
      }
      _catchItems.removeWhere((i) => i.type == CatchItemType.bacteria);
      
      _comboMultiplier = 1;
      _poopsCaughtConsecutively = 0;
      _spawnFloatingText(px, py, 'BOMBA DE CLORO 💣', Colors.redAccent, fontSize: 16);
      if (bacteriaCount > 0) {
        _spawnFloatingText(_gameWidth / 2, _gameHeight * 0.4, '¡$bacteriaCount bacterias desinfectadas! 🫧', Colors.greenAccent, fontSize: 14);
      }
    } else if (item.type == CatchItemType.bacteria) {
      if (_hasSoapShield) {
        _hasSoapShield = false;
        _soapShieldTicksRemaining = 0;
        _triggerShake(3.0, 8);
        HapticFeedback.mediumImpact();
        _spawnParticles(px, py, '🫧', 10);
        _spawnFloatingText(px, py, '¡ESCUDO ROTO!', Colors.blueAccent);
      } else {
        HapticFeedback.vibrate();
        _lives--;
        _spawnFloatingText(px, py, '-1 Vida 💔', Colors.redAccent);
        _triggerShake(8.0, 12);
        _triggerFlash(Colors.redAccent.withAlpha(120), 8);
        _spawnParticles(px, py, '💥', 10);
        
        if (_comboMultiplier > 1) {
          _spawnFloatingText(px, py, '¡COMBO ROTO! ❌', Colors.redAccent, fontSize: 14);
        }
        _comboMultiplier = 1;
        _poopsCaughtConsecutively = 0;

        if (_lives <= 0) {
          _isCacaCatchGameOver = true;
          _stopCacaCatch();
          widget.onGameOver(_score);
        }
      }
    }
  }

  // ==========================================



  // --- AREA JUEGO 1: CACA CATCH ---


  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    _gameWidth = size.width;
    _gameHeight = size.height;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text('PUNTUACIÓN: $_score', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                if (_comboMultiplier > 1) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'x$_comboMultiplier',
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 10),
                    ),
                  ),
                ],
              ],
            ),
            Row(
              children: List.generate(max(3, _lives), (i) => Icon(
                i < _lives ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: Colors.redAccent,
                size: 20,
              )),
            ),
            Row(
              children: [
                IconButton(
                  icon: Icon(_isPausedLocal ? Icons.play_arrow_rounded : Icons.pause_rounded, color: Colors.grey, size: 18),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      if (!_isCacaCatchGameOver) {
                        _isPausedLocal = !_isPausedLocal;
                        if (!_isPausedLocal) {
                          
                        }
                      }
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.grey, size: 18),
                  onPressed: () => widget.onGameOver(0),
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
                if (_ticker == null && !_isCacaCatchGameOver && !_isPausedLocal) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _ticker == null) {
                      _startCacaCatch();
                    }
                  });
                }
              }

              return Transform.translate(
                offset: Offset(_shakeX, _shakeY),
                child: GestureDetector(
                  onPanUpdate: (details) {
                    if (_isPausedLocal || _isCacaCatchGameOver) return;
                    setState(() {
                      double multiplier = _isSodaFrenzy ? 1.8 : 1.0;
                      if (widget.activeBuffCategory == AchievementCategory.stats) multiplier += 0.15;
                      _toiletX = (_toiletX + (details.delta.dx * multiplier) / _gameWidth).clamp(0.08, 0.92);
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D0D0D),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isFeverMode 
                            ? Colors.amber.withAlpha(120) 
                            : Colors.amberAccent.withAlpha(30),
                        width: _isFeverMode ? 2.0 : 1.0,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: RepaintBoundary(
                              child: CustomPaint(
                                painter: CacaCatchPainter(
                                  items: _catchItems,
                                  toiletX: _toiletX,
                                  particles: _particles,
                                  hasSoapShield: _hasSoapShield,
                                  isSodaFrenzy: _isSodaFrenzy,
                                  isFeverMode: _isFeverMode,
                                  width: _gameWidth,
                                  height: _gameHeight,
                                  floatingTexts: _floatingTexts,
                                  level: _level,
                                  cachedToiletImage: _cachedToiletImage,
                                  cachedBacteriaImage: _cachedBacteriaImage,
                                  cachedSoapImage: _cachedSoapImage,
                                  cachedSodaImage: _cachedSodaImage,
                                  cachedBombImage: _cachedBombImage,
                                  cachedPoopImage: _cachedPoopImage,
                                  cachedGoldenPoopImage: _cachedGoldenPoopImage,
                                  toiletFlashColor: _toiletFlashColor,
                                  toiletFlashTimer: _toiletFlashTimer,
                                  soapShieldTicksRemaining: _soapShieldTicksRemaining,
                                  sodaFrenzyTicksRemaining: _sodaFrenzyTicksRemaining,
                                  feverTicksRemaining: _feverTicksRemaining,
                                ),
                              ),
                            ),
                          ),

                          Positioned(
                            bottom: 8,
                            left: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: const Text(
                                '📖 Atrapa: 💩 (+1) 🧼 (+3) 🧽 (Escudo) ⭐ (Fiebre)  |  🔴 Evita: 👾 (Daño)',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          if (_flashColor != null)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Container(color: _flashColor),
                              ),
                            ),
                          if (_isCacaCatchGameOver)
                            InGameOverlay(
                              showPause: false,
                              showGameOver: _isCacaCatchGameOver,
                              title: 'CACA CATCH',
                              record: widget.highScore,
                              accentColor: Colors.amberAccent,
                              onRestart: () {
                                _startCacaCatch();
                              },
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
          ),
        ),
      ],
    );
  }


}
