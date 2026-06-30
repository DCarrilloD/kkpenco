import 'package:flutter/material.dart';
import 'dart:math';

class GameParticle {
  double x;
  double y;
  double vx;
  double vy;
  String emoji;
  double opacity;
  double scale;
  int lifeTime;
  int maxLifeTime;

  GameParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.emoji,
    this.opacity = 1.0,
    this.scale = 1.0,
    required this.lifeTime,
  }) : maxLifeTime = lifeTime;

  void update(double dt) {
    x += vx * dt * 33.3;
    y += vy * dt * 33.3;
    lifeTime--;
    opacity = (lifeTime / maxLifeTime).clamp(0.0, 1.0);
  }
}

// --- CACA CATCH ---
enum CatchItemType { poop, paper, bacteria, soap, goldenPoop, soda, chlorineBomb, picante }

class FloatingText {
  double x;
  double y;
  double vx;
  double vy;
  String text;
  Color color;
  double fontSize;
  double opacity;
  double scale;
  int lifeTime;
  int maxLifeTime;

  FloatingText({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.text,
    required this.color,
    this.fontSize = 16.0,
    this.opacity = 1.0,
    this.scale = 1.0,
    required this.lifeTime,
  }) : maxLifeTime = lifeTime;

  void update(double dt) {
    x += vx * dt * 60;
    y += vy * dt * 60;
    lifeTime--;
    opacity = (lifeTime / maxLifeTime).clamp(0.0, 1.0);
    scale = 0.8 + 0.4 * (lifeTime / maxLifeTime);
  }
}

// --- POOP INVADERS ---
class PoopSkinDrawer {
  static void drawPoop(
    Canvas canvas,
    Offset center,
    double size, {
    required String skin,
    double rotation = 0,
    double scaleX = 1.0,
    double scaleY = 1.0,
    Color? customColor,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.scale(scaleX, scaleY);

    final double half = size / 2;

    // 1. Determinar colores y estilos según la skin
    Color baseColor = Colors.brown[800]!;
    Color midColor = Colors.brown[600]!;
    Color topColor = Colors.brown[400]!;
    Color eyeColor = Colors.black;
    Color eyeReflectColor = Colors.white;

    Shader? customShader;
    bool isFever = skin == '🔥';
    bool isRainbow = skin == '🌈';
    bool isUnicorn = skin == '🦄';
    bool isAlien = skin == '👽';
    bool isRobot = skin == '🤖';

    if (isFever) {
      baseColor = Colors.redAccent[700]!;
      midColor = Colors.orangeAccent[700]!;
      topColor = Colors.yellow[600]!;
    } else if (isRainbow) {
      final rect = Rect.fromCircle(center: Offset.zero, radius: half);
      customShader = const LinearGradient(
        colors: [
          Colors.red,
          Colors.orange,
          Colors.yellow,
          Colors.green,
          Colors.blue,
          Colors.purple,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
    } else if (isUnicorn) {
      baseColor = const Color(0xFFFFC2D1); // Rosa pastel premium
      midColor = const Color(0xFFFFE5EC);
      topColor = const Color(0xFFFFF0F5);
    } else if (isAlien) {
      baseColor = const Color(0xFF39FF14); // Verde alien neón
      midColor = const Color(0xFF76FF03);
      topColor = const Color(0xFFCCFF90);
    } else if (isRobot) {
      baseColor = const Color(0xFF475569); // Acero oscuro
      midColor = const Color(0xFF64748B);  // Acero brillante
      topColor = const Color(0xFF94A3B8);  // Acero pulido
    } else if (skin == '👑') {
      baseColor = const Color(0xFF5C382C); // Marrón chocolate con matiz real
      midColor = Colors.brown[500]!;
      topColor = Colors.brown[300]!;
    } else if (skin == '😎') {
      baseColor = const Color(0xFF4E2C1E); // Marrón molón
      midColor = Colors.brown[500]!;
      topColor = Colors.brown[300]!;
    }

    // Sobrescribir si hay color personalizado (bacterias/partículas)
    if (customColor != null) {
      baseColor = customColor;
      midColor = customColor.withAlpha(200);
      topColor = customColor.withAlpha(150);
    }

    final int timeMs = DateTime.now().millisecondsSinceEpoch;

    // 2. DIBUJAR LLAMAS EN LA ESPALDA (Skin Fuego / Fiebre)
    if (isFever) {
      final double wave1 = sin(timeMs * 0.015) * 5.0;
      final double wave2 = cos(timeMs * 0.02) * 4.0;

      final Paint flamePaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
          colors: const [Colors.yellow, Colors.orangeAccent, Colors.redAccent, Colors.transparent],
          stops: const [0.0, 0.45, 0.85, 1.0],
          center: Alignment(0, 0.2 + 0.1 * sin(timeMs * 0.01)),
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: half * 1.4));

      final flamePath = Path();
      // Llama izquierda
      flamePath.moveTo(-half * 0.85, half * 0.3);
      flamePath.quadraticBezierTo(-half * 1.3 + wave1, -half * 0.4 + wave2, -half * 0.45, -half * 0.7);
      flamePath.quadraticBezierTo(-half * 0.55, half * 0.1, -half * 0.35, half * 0.3);
      
      // Llama central gigante
      flamePath.moveTo(-half * 0.35, half * 0.3);
      flamePath.quadraticBezierTo(wave1, -half * 1.5 + wave2, half * 0.15, -half * 1.0);
      flamePath.quadraticBezierTo(-half * 0.1, 0, half * 0.35, half * 0.3);

      // Llama derecha
      flamePath.moveTo(half * 0.35, half * 0.3);
      flamePath.quadraticBezierTo(half * 1.3 - wave2, -half * 0.4 + wave1, half * 0.45, -half * 0.7);
      flamePath.quadraticBezierTo(half * 0.55, half * 0.1, half * 0.85, half * 0.3);
      flamePath.close();
      canvas.drawPath(flamePath, flamePaint);

      // Chispas de fuego ascendentes
      final Random sparkRand = Random(1234);
      for (int i = 0; i < 4; i++) {
        final double seed = sparkRand.nextDouble();
        final double spX = (seed - 0.5) * half * 1.8;
        final double spY = (half * 0.5) - ((timeMs * 0.05 * (0.8 + seed) + i * 20) % (half * 2.0));
        final double spRadius = 1.5 + seed * 2.0;
        if (spY > -half * 1.6) {
          canvas.drawCircle(
            Offset(spX, spY),
            spRadius,
            Paint()
              ..color = Colors.amberAccent.withAlpha((180 + seed * 75).toInt())
              ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 1),
          );
        }
      }
    }

    // 3. SILUETA BASE CON GRADIENTE RADIAL EXCENTRICO (Volumen 3D)
    final Paint poopPaint = Paint()..style = PaintingStyle.fill;
    
    if (customShader != null) {
      poopPaint.shader = customShader;
    } else {
      poopPaint.shader = RadialGradient(
        colors: [midColor, baseColor],
        stops: const [0.3, 1.0],
        center: const Alignment(-0.25, -0.3), // Luz desde arriba a la izquierda
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: half * 1.1));
    }

    final poopPath = Path();
    // Base inferior
    poopPath.moveTo(-half * 0.82, half * 0.52);
    poopPath.cubicTo(-half * 0.82, half * 0.98, half * 0.82, half * 0.98, half * 0.82, half * 0.52);
    
    // Capa inferior derecha
    poopPath.cubicTo(half * 1.18, half * 0.52, half * 1.12, half * 0.12, half * 0.72, half * 0.05);
    // Capa media derecha
    poopPath.cubicTo(half * 0.92, half * 0.05, half * 0.77, -half * 0.28, half * 0.37, -half * 0.33);
    // Punta enrollada arriba
    poopPath.cubicTo(half * 0.47, -half * 0.38, half * 0.27, -half * 0.83, 0, -half * 0.83);
    poopPath.cubicTo(-half * 0.22, -half * 0.83, -half * 0.32, -half * 0.63, -half * 0.14, -half * 0.53);
    
    // Capa media izquierda
    poopPath.cubicTo(-half * 0.47, -half * 0.53, -half * 0.57, -half * 0.18, -half * 0.37, -half * 0.13);
    // Capa inferior izquierda
    poopPath.cubicTo(-half * 0.82, -half * 0.13, -half * 0.92, half * 0.27, -half * 0.72, half * 0.32);
    
    // Cerrar con curvatura suave
    poopPath.quadraticBezierTo(-half * 0.92, half * 0.42, -half * 0.82, half * 0.52);
    poopPath.close();

    // Sombra del cuerpo proyectada en el fondo (Glow sutil)
    final shadowPaint = Paint()
      ..color = Colors.black.withAlpha(65)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawPath(poopPath, shadowPaint);

    // Dibujar la base
    canvas.drawPath(poopPath, poopPaint);

    // 4. CAPAS DE ESPIRAL EN 3D CON GRADIENTES RADIALES EXCENTRICOS
    if (!isRainbow) {
      // --- Capa media interna ---
      final Paint midLayerPaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
          colors: [topColor, midColor],
          stops: const [0.2, 1.0],
          center: const Alignment(-0.25, -0.3),
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: half * 0.8));

      final midPath = Path();
      midPath.moveTo(-half * 0.62, half * 0.27);
      midPath.cubicTo(-half * 0.62, half * 0.52, half * 0.62, half * 0.52, half * 0.62, half * 0.27);
      midPath.cubicTo(half * 0.82, half * 0.27, half * 0.72, -half * 0.08, half * 0.32, -half * 0.13);
      midPath.cubicTo(-half * 0.08, -half * 0.13, -half * 0.42, -half * 0.03, -half * 0.52, half * 0.17);
      midPath.close();
      canvas.drawPath(midPath, midLayerPaint);

      // --- Capa superior interna ---
      final Paint topLayerPaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
          colors: [Color.lerp(Colors.white, topColor, 0.4)!, topColor],
          stops: const [0.1, 1.0],
          center: const Alignment(-0.2, -0.2),
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: half * 0.55));

      final topPath = Path();
      topPath.moveTo(-half * 0.37, -half * 0.08);
      topPath.cubicTo(-half * 0.37, half * 0.12, half * 0.37, half * 0.12, half * 0.37, -half * 0.08);
      topPath.cubicTo(half * 0.47, -half * 0.08, half * 0.37, -half * 0.48, 0, -half * 0.53);
      topPath.cubicTo(-half * 0.27, -half * 0.48, -half * 0.37, -half * 0.28, -half * 0.37, -half * 0.08);
      topPath.close();
      canvas.drawPath(topPath, topLayerPaint);

      // --- Brillo 3D en la base inferior ---
      final Paint baseShinePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.04
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withAlpha(90);
      canvas.drawArc(
        Rect.fromCenter(center: Offset(0, half * 0.45), width: size * 0.65, height: size * 0.22),
        2.5,
        1.2,
        false,
        baseShinePaint..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
      );
    }

    // Brillo blanco reflectante de borde izquierdo general (Candy effect)
    final lightPaint = Paint()
      ..color = Colors.white.withAlpha(95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.045
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8);
    final lightPath = Path();
    lightPath.moveTo(-half * 0.58, half * 0.42);
    lightPath.quadraticBezierTo(-half * 0.72, half * 0.18, -half * 0.52, -half * 0.02);
    lightPath.quadraticBezierTo(-half * 0.38, -half * 0.22, -half * 0.22, -half * 0.42);
    canvas.drawPath(lightPath, lightPaint);

    // 5. ACCESORIOS PREMIUM
    // --- CUERNO DE UNICORNIO (Cristalino 3D) ---
    if (isUnicorn) {
      final hornPaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = const LinearGradient(
          colors: [
            Color(0xFFFFD54F),
            Color(0xFFFFF176),
            Color(0xFFFFE082),
            Color(0xFFFFB74D),
          ],
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
        ).createShader(Rect.fromLTWH(-half * 0.15, -half * 1.45, half * 0.3, half * 0.75));
      
      final hornPath = Path();
      hornPath.moveTo(-half * 0.14, -half * 0.7);
      hornPath.lineTo(0, -half * 1.45);
      hornPath.lineTo(half * 0.14, -half * 0.7);
      hornPath.close();
      canvas.drawPath(hornPath, hornPaint);

      // Líneas de relieve del cuerno
      final linePaint = Paint()
        ..color = const Color(0xFFE5A93C).withAlpha(120)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8;
      canvas.drawLine(Offset(-half * 0.09, -half * 0.9), Offset(half * 0.09, -half * 0.94), linePaint);
      canvas.drawLine(Offset(-half * 0.07, -half * 1.1), Offset(half * 0.07, -half * 1.14), linePaint);
      canvas.drawLine(Offset(-half * 0.04, -half * 1.3), Offset(half * 0.04, -half * 1.33), linePaint);

      // Destellos mágicos brillantes a su alrededor
      final double magicGlow = 0.5 + 0.5 * sin(timeMs * 0.01).abs();
      final Paint sparkPaint = Paint()
        ..color = Colors.white.withAlpha((magicGlow * 255).toInt())
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2);
      canvas.drawCircle(Offset(-half * 0.3, -half * 1.2), 2.5, sparkPaint);
      canvas.drawCircle(Offset(half * 0.3, -half * 1.1), 2.0, sparkPaint);
    }

    // --- CORONA REAL (Oro 3D con Destellos) ---
    if (skin == '👑') {
      final crownPaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = const LinearGradient(
          colors: [
            Color(0xFFFFD700), // Oro puro
            Color(0xFFFFA000), // Oro medio
            Color(0xFFE65100), // Oro profundo
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(-half * 0.42, -half * 1.25, half * 0.84, half * 0.55));

      final crownPath = Path();
      crownPath.moveTo(-half * 0.37, -half * 0.65);
      crownPath.lineTo(-half * 0.44, -half * 1.18); // Punta izquierda
      crownPath.lineTo(-half * 0.16, -half * 0.88);
      crownPath.lineTo(0, -half * 1.28); // Punta central
      crownPath.lineTo(half * 0.16, -half * 0.88);
      crownPath.lineTo(half * 0.44, -half * 1.18); // Punta derecha
      crownPath.lineTo(half * 0.37, -half * 0.65);
      crownPath.close();
      canvas.drawPath(crownPath, crownPaint);
      canvas.drawPath(crownPath, Paint()..color = const Color(0xFF8D6E63)..style = PaintingStyle.stroke..strokeWidth = 0.8);

      // Gemas facetadas de rubí y esmeralda con destellos
      final Paint ruby = Paint()
        ..shader = const RadialGradient(colors: [Colors.white, Colors.redAccent, Color(0xFFD50000)]).createShader(Rect.fromCircle(center: Offset(0, -half * 0.88), radius: size * 0.065));
      canvas.drawCircle(Offset(0, -half * 0.88), size * 0.055, ruby);
      
      final Paint emerald = Paint()
        ..shader = const RadialGradient(colors: [Colors.white, Colors.lightGreenAccent, Color(0xFF1B5E20)]).createShader(Rect.fromCircle(center: Offset(-half * 0.22, -half * 0.76), radius: size * 0.045));
      canvas.drawCircle(Offset(-half * 0.22, -half * 0.76), size * 0.04, emerald);

      final Paint sapphire = Paint()
        ..shader = const RadialGradient(colors: [Colors.white, Colors.blueAccent, Color(0xFF0D47A1)]).createShader(Rect.fromCircle(center: Offset(half * 0.22, -half * 0.76), radius: size * 0.045));
      canvas.drawCircle(Offset(half * 0.22, -half * 0.76), size * 0.04, sapphire);

      // Perlas en los picos de la corona
      final Paint pearl = Paint()..color = const Color(0xFFFFFDE7);
      canvas.drawCircle(Offset(-half * 0.44, -half * 1.18), size * 0.045, pearl);
      canvas.drawCircle(Offset(0, -half * 1.28), size * 0.05, pearl);
      canvas.drawCircle(Offset(half * 0.44, -half * 1.18), size * 0.045, pearl);

      // Destello vectorial (+) en la gema central
      final Paint sparklePaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 1.2;
      canvas.drawLine(Offset(-6, -half * 0.88), Offset(6, -half * 0.88), sparklePaint);
      canvas.drawLine(Offset(0, -half * 0.88 - 6), Offset(0, -half * 0.88 + 6), sparklePaint);
    }

    // 6. DIBUJAR OJOS Y EXPRESIÓN
    if (isAlien) {
      // Ojos galácticos gigantes
      final Paint alienEyePaint = Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF1A237E), Color(0xFF000000)],
          stops: [0.3, 1.0],
        ).createShader(Rect.fromCenter(center: Offset(-half * 0.28, -half * 0.1), width: size * 0.16, height: size * 0.3));
      
      canvas.save();
      canvas.translate(-half * 0.28, -half * 0.1);
      canvas.rotate(0.32);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: size * 0.16, height: size * 0.3), alienEyePaint);
      // Doble reflejo alienígena
      canvas.drawCircle(const Offset(-3, -6), size * 0.038, Paint()..color = Colors.white);
      canvas.drawCircle(const Offset(2, 4), size * 0.015, Paint()..color = Colors.white.withAlpha(180));
      canvas.restore();

      final Paint alienEyePaintR = Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF1A237E), Color(0xFF000000)],
          stops: [0.3, 1.0],
        ).createShader(Rect.fromCenter(center: Offset(half * 0.28, -half * 0.1), width: size * 0.16, height: size * 0.3));

      canvas.save();
      canvas.translate(half * 0.28, -half * 0.1);
      canvas.rotate(-0.32);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: size * 0.16, height: size * 0.3), alienEyePaintR);
      canvas.drawCircle(const Offset(3, -6), size * 0.038, Paint()..color = Colors.white);
      canvas.drawCircle(const Offset(-2, 4), size * 0.015, Paint()..color = Colors.white.withAlpha(180));
      canvas.restore();
      
      final alienMouthPaint = Paint()
        ..color = const Color(0xFF1B5E20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCenter(center: Offset(0, half * 0.22), width: size * 0.18, height: size * 0.08),
        0.1,
        pi - 0.2,
        false,
        alienMouthPaint,
      );
    } else if (isRobot) {
      // Visor de escáner cibernético
      final visorBgPaint = Paint()..color = const Color(0xFF1E293B);
      final visorRect = Rect.fromCenter(center: Offset(0, -half * 0.1), width: size * 0.62, height: size * 0.2);
      canvas.drawRRect(RRect.fromRectAndRadius(visorRect, const Radius.circular(5)), visorBgPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(visorRect, const Radius.circular(5)), Paint()..color = const Color(0xFF0F172A)..style = PaintingStyle.stroke..strokeWidth = 1.0);

      // Rayo láser neón
      final Paint laserPaint = Paint()
        ..color = Colors.redAccent
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(-half * 0.24, -half * 0.1), Offset(half * 0.24, -half * 0.1), laserPaint);

      // Escáner brillante oscilante
      final double scanPos = sin(timeMs * 0.006) * half * 0.2;
      final laserGlow = Paint()
        ..color = Colors.redAccent.withAlpha(150)
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 5);
      canvas.drawCircle(Offset(scanPos, -half * 0.1), 5.5, laserGlow);
      canvas.drawCircle(Offset(scanPos, -half * 0.1), 2.2, Paint()..color = Colors.white);
      
      // Rejilla de altavoz robótica
      final grillPaint = Paint()
        ..color = const Color(0xFF1E293B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawLine(Offset(-half * 0.18, half * 0.2), Offset(half * 0.18, half * 0.2), grillPaint);
      canvas.drawLine(Offset(-half * 0.1, half * 0.15), Offset(-half * 0.1, half * 0.25), grillPaint);
      canvas.drawLine(Offset(0, half * 0.15), Offset(0, half * 0.25), grillPaint);
      canvas.drawLine(Offset(half * 0.1, half * 0.15), Offset(half * 0.1, half * 0.25), grillPaint);

      // Remaches metálicos de cabeza robótica
      final Paint rivet = Paint()..color = const Color(0xFF334155);
      canvas.drawCircle(Offset(-half * 0.5, -half * 0.35), 2.0, rivet);
      canvas.drawCircle(Offset(half * 0.5, -half * 0.35), 2.0, rivet);
    } else {
      // Ojos normales con volumen y doble brillo especular
      final double eyeWidth = size * 0.13;
      final double eyeHeight = size * 0.16;
      final double eyeOffsetX = half * 0.26;
      final double eyeOffsetY = -half * 0.1;

      // Ojo izquierdo
      canvas.drawOval(
        Rect.fromCenter(center: Offset(-eyeOffsetX, eyeOffsetY), width: eyeWidth, height: eyeHeight),
        Paint()..color = eyeColor,
      );
      canvas.drawCircle(
        Offset(-eyeOffsetX - 2.5, eyeOffsetY - 2.5),
        size * 0.045,
        Paint()..color = eyeReflectColor,
      );
      canvas.drawCircle(
        Offset(-eyeOffsetX + 2.0, eyeOffsetY + 2.0),
        size * 0.018,
        Paint()..color = eyeReflectColor.withAlpha(180),
      );

      // Ojo derecho
      canvas.drawOval(
        Rect.fromCenter(center: Offset(eyeOffsetX, eyeOffsetY), width: eyeWidth, height: eyeHeight),
        Paint()..color = eyeColor,
      );
      canvas.drawCircle(
        Offset(eyeOffsetX - 2.5, eyeOffsetY - 2.5),
        size * 0.045,
        Paint()..color = eyeReflectColor,
      );
      canvas.drawCircle(
        Offset(eyeOffsetX + 2.0, eyeOffsetY + 2.0),
        size * 0.018,
        Paint()..color = eyeReflectColor.withAlpha(180),
      );

      // Cejas expresivas
      final Paint browPaint = Paint()
        ..color = const Color(0xFF3E2723)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      
      canvas.drawArc(
        Rect.fromCenter(center: Offset(-eyeOffsetX, eyeOffsetY - 8), width: eyeWidth * 1.2, height: 6),
        3.4,
        1.2,
        false,
        browPaint,
      );
      canvas.drawArc(
        Rect.fromCenter(center: Offset(eyeOffsetX, eyeOffsetY - 8), width: eyeWidth * 1.2, height: 6),
        3.8,
        1.2,
        false,
        browPaint,
      );

      if (isUnicorn) {
        // Mejillas rosadas dulces en 3D
        final cheekPaint = Paint()
          ..color = const Color(0xFFFF4081).withAlpha(95)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
        canvas.drawOval(Rect.fromCenter(center: Offset(-eyeOffsetX * 1.5, eyeOffsetY + 9), width: 14, height: 8), cheekPaint);
        canvas.drawOval(Rect.fromCenter(center: Offset(eyeOffsetX * 1.5, eyeOffsetY + 9), width: 14, height: 8), cheekPaint);
      }

      if (skin == '😎') {
        // Gafas Cyberpunk Vaporwave
        final Paint glassesPaint = Paint()
          ..shader = const LinearGradient(
            colors: [Colors.purpleAccent, Colors.cyanAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(Rect.fromLTWH(-half * 0.6, -half * 0.28, half * 1.2, half * 0.45));
        
        final glassesBorder = Paint()
          ..color = const Color(0xFF0F172A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2;

        final lLens = Path()
          ..moveTo(-half * 0.58, -half * 0.26)
          ..lineTo(-half * 0.06, -half * 0.26)
          ..quadraticBezierTo(-half * 0.08, half * 0.18, -half * 0.32, half * 0.18)
          ..quadraticBezierTo(-half * 0.55, half * 0.18, -half * 0.58, -half * 0.26)
          ..close();
        canvas.drawPath(lLens, glassesPaint);
        canvas.drawPath(lLens, glassesBorder);

        final rLens = Path()
          ..moveTo(half * 0.06, -half * 0.26)
          ..lineTo(half * 0.58, -half * 0.26)
          ..quadraticBezierTo(half * 0.55, half * 0.18, (half * 0.32), half * 0.18)
          ..quadraticBezierTo(half * 0.08, half * 0.18, half * 0.06, -half * 0.26)
          ..close();
        canvas.drawPath(rLens, glassesPaint);
        canvas.drawPath(rLens, glassesBorder);

        // Puente de las gafas
        canvas.drawLine(Offset(-half * 0.06, -half * 0.21), Offset(half * 0.06, -half * 0.21), Paint()..color = const Color(0xFF0F172A)..strokeWidth = 3.5);

        // Reflejos especulares blancos en las gafas
        final reflectPaint = Paint()
          ..color = Colors.white.withAlpha(140)
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(-half * 0.48, -half * 0.16), Offset(-half * 0.38, half * 0.06), reflectPaint);
        canvas.drawLine(Offset(half * 0.16, -half * 0.16), Offset(half * 0.26, half * 0.06), reflectPaint);
      } else {
        // Sonrisa alegre en 3D
        final smilePaint = Paint()
          ..color = eyeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = size * 0.05
          ..strokeCap = StrokeCap.round;
        
        final smileRect = Rect.fromCenter(
          center: Offset(0, eyeOffsetY + size * 0.18),
          width: size * 0.18,
          height: size * 0.08,
        );
        canvas.drawArc(
          smileRect,
          0.25,
          pi - 0.5,
          false,
          smilePaint,
        );
      }
    }

    canvas.restore();
  }
}

class StoreSkinPainter extends CustomPainter {
  final String skin;
  final Color baseColor;

  StoreSkinPainter({required this.skin, required this.baseColor});

  @override
  void paint(Canvas canvas, Size size) {
    PoopSkinDrawer.drawPoop(
      canvas,
      Offset(size.width / 2, size.height / 2),
      size.width * 0.8,
      skin: skin,
    );
  }

  @override
  bool shouldRepaint(covariant StoreSkinPainter oldDelegate) {
    return oldDelegate.skin != skin || oldDelegate.baseColor != baseColor;
  }
}

class ToiletDrawer {
  static void drawToilet(
    Canvas canvas,
    Offset center,
    double size, {
    bool isInvaderShip = false,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);

    final double half = size / 2;

    // Contorno/borde metálico de toda la estructura
    final Paint rimPaint = Paint()
      ..color = const Color(0xFF475569) // Gris azulado más oscuro y profesional
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Gradiente diagonal para porcelana blanca 3D
    final Paint whitePorcelainPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFFFFFFF), // Reflejo directo de luz
          Color(0xFFF8FAFC), // Blanco porcelana
          Color(0xFFE2E8F0), // Sombra suave
          Color(0xFF94A3B8), // Sombra ocluida
        ],
        stops: [0.0, 0.35, 0.75, 1.0],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: half));

    // Pintura para el brillo cerámico especular (tipo cristal vidriado)
    final Paint porcelainShinePaint = Paint()
      ..color = Colors.white.withAlpha(200)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size * 0.035
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);

    // --- 1. DETALLES DE LA NAVE ESPACIAL (Sólo Poop Invaders) ---
    if (isInvaderShip) {
      final int timeMs = DateTime.now().millisecondsSinceEpoch;
      
      // Llamas oscilantes del propulsor de agua a presión
      final double flicker = 0.8 + 0.2 * sin(timeMs * 0.02);
      final double flameHeight = half * 0.75 * flicker;
      
      final Paint thrustPaint = Paint()
        ..shader = const LinearGradient(
          colors: [
            Colors.cyanAccent,
            Colors.blueAccent,
            Colors.transparent,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(-half * 0.8, half * 0.4, half * 1.6, flameHeight));
        
      final leftThrust = Path()
        ..moveTo(-half * 0.45, half * 0.4)
        ..lineTo(-half * 0.6, half * 0.4 + flameHeight)
        ..lineTo(-half * 0.3, half * 0.4)
        ..close();
      final rightThrust = Path()
        ..moveTo(half * 0.3, half * 0.4)
        ..lineTo(half * 0.6, half * 0.4 + flameHeight)
        ..lineTo(half * 0.45, half * 0.4)
        ..close();
        
      canvas.drawPath(leftThrust, thrustPaint);
      canvas.drawPath(rightThrust, thrustPaint);

      // Partículas de agua propulsada
      final Random rand = Random(456);
      for (int i = 0; i < 6; i++) {
        final double pOffsetX = (rand.nextDouble() - 0.5) * half * 0.6;
        final double pOffsetY = half * 0.45 + (rand.nextDouble() * flameHeight * 0.8);
        final double pRadius = 1.5 + rand.nextDouble() * 2.0;
        final int pOpacity = (100 + rand.nextDouble() * 155).toInt();
        canvas.drawCircle(
          Offset(pOffsetX + (i % 2 == 0 ? -half * 0.45 : half * 0.45), pOffsetY),
          pRadius,
          Paint()..color = Colors.cyanAccent.withAlpha(pOpacity),
        );
      }

      // Alas mecánicas de metal espacial cepillado
      final Paint wingPaint = Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFF64748B), // Slate medio
            Color(0xFF475569), // Slate oscuro
            Color(0xFF1E293B), // Slate muy oscuro
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: half));

      final wingPath = Path();
      // Ala izquierda futurista
      wingPath.moveTo(-half * 0.3, half * 0.1);
      wingPath.lineTo(-half * 1.1, half * 0.32);
      wingPath.lineTo(-half * 1.1, half * 0.45);
      wingPath.lineTo(-half * 0.5, half * 0.45);
      wingPath.lineTo(-half * 0.2, half * 0.25);
      // Ala derecha futurista
      wingPath.moveTo(half * 0.3, half * 0.1);
      wingPath.lineTo(half * 1.1, half * 0.32);
      wingPath.lineTo(half * 1.1, half * 0.45);
      wingPath.lineTo(half * 0.5, half * 0.45);
      wingPath.lineTo(half * 0.2, half * 0.25);
      wingPath.close();

      canvas.drawPath(wingPath, wingPaint);
      canvas.drawPath(wingPath, rimPaint);

      // Pernos / Remaches mecánicos en las alas (efecto 3D)
      final Paint boltDark = Paint()..color = const Color(0xFF0F172A);
      final Paint boltLight = Paint()..color = const Color(0xFF94A3B8);
      final List<Offset> bolts = [
        Offset(-half * 0.6, half * 0.32),
        Offset(-half * 0.85, half * 0.38),
        Offset(half * 0.6, half * 0.32),
        Offset(half * 0.85, half * 0.38),
      ];
      for (var bolt in bolts) {
        canvas.drawCircle(bolt, 2.0, boltDark);
        canvas.drawCircle(bolt + const Offset(-0.5, -0.5), 1.0, boltLight);
      }

      // Luces LED de navegación parpadeantes (Cian en la izquierda, Magenta en la derecha)
      final double glowIntensity = 0.4 + 0.6 * sin(timeMs * 0.01).abs();
      final Paint leftLed = Paint()
        ..color = Colors.cyanAccent.withAlpha((glowIntensity * 255).toInt())
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);
      final Paint rightLed = Paint()
        ..color = Colors.pinkAccent.withAlpha((glowIntensity * 255).toInt())
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);

      canvas.drawCircle(Offset(-half * 1.1, half * 0.32), 3.5, leftLed);
      canvas.drawCircle(Offset(-half * 1.1, half * 0.32), 1.5, Paint()..color = Colors.white);

      canvas.drawCircle(Offset(half * 1.1, half * 0.32), 3.5, rightLed);
      canvas.drawCircle(Offset(half * 1.1, half * 0.32), 1.5, Paint()..color = Colors.white);

      // Cañón de agua superior
      final Paint cannonPaint = Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF334155), Color(0xFF64748B), Color(0xFF1E293B)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(Rect.fromLTWH(-half * 0.15, -half * 0.95, half * 0.3, half * 0.55));

      canvas.drawRect(Rect.fromLTWH(-half * 0.12, -half * 0.95, half * 0.24, half * 0.5), cannonPaint);
      canvas.drawRect(Rect.fromLTWH(-half * 0.12, -half * 0.95, half * 0.24, half * 0.5), rimPaint);

      // Recámara y boquilla de plasma de agua cargada
      final Paint activeNozzle = Paint()
        ..color = Colors.cyanAccent
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3);
      canvas.drawRect(Rect.fromLTWH(-half * 0.15, -half * 1.02, half * 0.3, half * 0.08), activeNozzle);
      canvas.drawCircle(Offset(0, -half * 1.02), 2.5, Paint()..color = Colors.white);
    }

    // --- 2. EL TANQUE DE AGUA TRASERO ---
    final tankRect = Rect.fromCenter(
      center: Offset(0, -half * 0.36),
      width: size * 0.72,
      height: size * 0.38,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(tankRect, const Radius.circular(10)), whitePorcelainPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(tankRect, const Radius.circular(10)), rimPaint);

    // Detalle de brillo en el tanque
    canvas.drawArc(
      Rect.fromLTWH(-half * 0.3, -half * 0.5, half * 0.6, half * 0.1),
      3.14,
      1.57,
      false,
      porcelainShinePaint..strokeWidth = 2.0,
    );

    // Botón de descarga de oro pulido
    final Paint goldButtonPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFFFE082), Color(0xFFFFD54F), Color(0xFFFFB300), Color(0xFFB57C00)],
        stops: [0.0, 0.3, 0.75, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(half * 0.22, -half * 0.36), radius: size * 0.055));
    canvas.drawCircle(Offset(half * 0.22, -half * 0.36), size * 0.045, goldButtonPaint);
    canvas.drawCircle(Offset(half * 0.22, -half * 0.36), size * 0.045, rimPaint..strokeWidth = 0.8);
    canvas.drawCircle(Offset(half * 0.20, -half * 0.38), size * 0.015, Paint()..color = Colors.white.withAlpha(200));

    // --- 3. PIE Y CONECTOR DE LA TAZA (EFECTO VOLUMÉTRICO) ---
    final baseConnector = Path()
      ..moveTo(-half * 0.36, -half * 0.1)
      ..lineTo(-half * 0.48, half * 0.44)
      ..lineTo(half * 0.48, half * 0.44)
      ..lineTo(half * 0.36, -half * 0.1)
      ..close();
    canvas.drawPath(baseConnector, whitePorcelainPaint);
    canvas.drawPath(baseConnector, rimPaint);

    // Sombra interna del conector para simular volumen cóncavo
    final Paint connectorShadow = Paint()
      ..shader = LinearGradient(
        colors: [Colors.black.withAlpha(80), Colors.transparent],
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      ).createShader(Rect.fromLTWH(-half * 0.5, 0, half * 1.0, half * 0.44));
    canvas.drawPath(baseConnector, connectorShadow);

    // Base del suelo
    final floorBase = Rect.fromCenter(
      center: Offset(0, half * 0.43),
      width: size * 0.78,
      height: size * 0.12,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(floorBase, const Radius.circular(8)), whitePorcelainPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(floorBase, const Radius.circular(8)), rimPaint);

    // --- 4. TAZA DEL INODORO ---
    final bowlRect = Rect.fromCenter(
      center: Offset(0, half * 0.06),
      width: size * 0.76,
      height: size * 0.54,
    );
    canvas.drawOval(bowlRect, whitePorcelainPaint);
    canvas.drawOval(bowlRect, rimPaint);

    // --- 5. AGUA CELESTE NEÓN 3D PROFUNDA ---
    final waterRect = Rect.fromCenter(
      center: Offset(0, half * 0.08),
      width: size * 0.58,
      height: size * 0.38,
    );
    
    final Paint waterPaint = Paint()
      ..shader = const RadialGradient(
        colors: [
          Colors.cyanAccent,
          Color(0xFF00E5FF),
          Color(0xFF00ACC1),
          Color(0xFF006064),
        ],
        stops: [0.0, 0.4, 0.8, 1.0],
        center: Alignment(-0.15, -0.15),
      ).createShader(waterRect);
    canvas.drawOval(waterRect, waterPaint);

    // Burbujas ascendentes en el agua (animadas con el tiempo del sistema)
    final int ms = DateTime.now().millisecondsSinceEpoch;
    final Random bubbleRand = Random(789);
    for (int i = 0; i < 4; i++) {
      final double seed = bubbleRand.nextDouble();
      final double bSpeed = 0.5 + seed * 1.5;
      final double bOffsetY = (half * 0.22) - ((ms * 0.035 * bSpeed + i * 15) % (half * 0.3));
      final double bOffsetX = (seed - 0.5) * size * 0.35 + sin(ms * 0.005 + i).abs() * 5.0;
      final double bRadius = 1.0 + seed * 2.5;
      final int bOpacity = (80 + seed * 120).toInt();
      
      if (waterRect.contains(Offset(bOffsetX, bOffsetY + half * 0.08))) {
        canvas.drawCircle(
          Offset(bOffsetX, bOffsetY + half * 0.08),
          bRadius,
          Paint()
            ..color = Colors.white.withAlpha(bOpacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.6,
        );
        // Pequeño reflejo interior de la burbuja
        canvas.drawCircle(
          Offset(bOffsetX - bRadius * 0.3, bOffsetY + half * 0.08 - bRadius * 0.3),
          bRadius * 0.3,
          Paint()..color = Colors.white.withAlpha(bOpacity),
        );
      }
    }

    // Reflejo brillante de onda en el agua
    final Paint wavePaint = Paint()
      ..color = Colors.white.withAlpha(150)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(0, half * 0.09), width: size * 0.44, height: size * 0.24),
      0.3,
      1.3,
      false,
      wavePaint,
    );

    // --- 6. ARO Y TAPA DE PORCELANA CON BRILLO ESPECULAR ---
    final seatRect = Rect.fromCenter(
      center: Offset(0, half * 0.02),
      width: size * 0.8,
      height: size * 0.58,
    );
    final seatPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.055
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFFFFFFF), // Brillo arriba
          Color(0xFFF1F5F9), // Cuerpo
          Color(0xFFCBD5E1), // Sombra abajo
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(seatRect);
    canvas.drawOval(seatRect, seatPaint);
    canvas.drawOval(seatRect, rimPaint..strokeWidth = 0.8);

    // Brillo blanco cerámico reflectante en el aro (iluminación principal)
    canvas.drawArc(
      Rect.fromCenter(center: Offset(0, half * 0.02), width: size * 0.74, height: size * 0.52),
      3.2,
      1.3,
      false,
      porcelainShinePaint,
    );

    canvas.restore();
  }
}

class BossDrawer {
  static void drawBoss(
    Canvas canvas,
    Offset center,
    double size, {
    required int level,
    required bool isRage,
    required int hitFlashTicks,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);

    final double half = size / 2;
    final int timeMs = DateTime.now().millisecondsSinceEpoch;
    final bool hasFlash = hitFlashTicks > 0;

    if (level == 1) {
      _drawSuperBacteria(canvas, half, timeMs, isRage, hasFlash);
    } else if (level == 2) {
      _drawAmebaMutante(canvas, half, timeMs, isRage, hasFlash);
    } else if (level == 3) {
      _drawGermenGigante(canvas, half, timeMs, isRage, hasFlash);
    } else {
      _drawVirusSupremo(canvas, half, timeMs, isRage, hasFlash);
    }

    canvas.restore();
  }

  static void _drawSuperBacteria(Canvas canvas, double half, int timeMs, bool isRage, bool hasFlash) {
    // 1. Cilios y flagelos ondulantes con físicas y esferas terminales de energía
    final Paint cilioPaint = Paint()
      ..color = hasFlash ? Colors.white : (isRage ? Colors.orangeAccent : Colors.greenAccent[400]!)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    
    final Paint tipPaint = Paint()
      ..color = hasFlash ? Colors.white : (isRage ? Colors.yellowAccent : Colors.cyanAccent)
      ..style = PaintingStyle.fill;

    const int cilioCount = 18;
    for (int i = 0; i < cilioCount; i++) {
      final double angle = (i * 2 * pi) / cilioCount;
      final double wave1 = sin(timeMs * 0.012 + i) * 6.0;
      final double wave2 = cos(timeMs * 0.02 + i) * 8.0;
      
      final double startRadius = half * 0.55;
      final double endRadius = half * 0.92 + wave1;
      
      final startX = cos(angle) * startRadius;
      final startY = sin(angle) * startRadius;
      
      final midX = cos(angle) * (startRadius + (endRadius - startRadius) * 0.5) + wave1 * sin(angle);
      final midY = sin(angle) * (startRadius + (endRadius - startRadius) * 0.5) - wave1 * cos(angle);
      
      final endX = cos(angle) * endRadius + wave2 * sin(angle);
      final endY = sin(angle) * endRadius - wave2 * cos(angle);
      
      final flageloPath = Path()
        ..moveTo(startX, startY)
        ..quadraticBezierTo(midX, midY, endX, endY);
      canvas.drawPath(flageloPath, cilioPaint);
      canvas.drawCircle(Offset(endX, endY), 2.8, tipPaint);
    }

    // 2. Respiración elíptica celular
    final double scaleX = 1.0 + 0.04 * sin(timeMs * 0.007);
    final double scaleY = 1.0 - 0.04 * sin(timeMs * 0.007);
    final double bodyRadiusX = half * 0.68 * scaleX;
    final double bodyRadiusY = half * 0.68 * scaleY;
    final Rect bodyRect = Rect.fromCenter(center: Offset.zero, width: bodyRadiusX * 2, height: bodyRadiusY * 2);

    final Paint bodyPaint = Paint()..style = PaintingStyle.fill;
    if (hasFlash) {
      bodyPaint.color = Colors.white;
    } else {
      bodyPaint.shader = RadialGradient(
        colors: isRage 
            ? [Colors.orangeAccent, Colors.red[950]!] 
            : [Colors.greenAccent[400]!, const Color(0xFF063B12)],
        stops: const [0.15, 1.0],
        center: const Alignment(-0.25, -0.25),
      ).createShader(bodyRect);
    }
    
    // Dibujar cuerpo celular elíptico
    canvas.drawOval(bodyRect, bodyPaint);
    canvas.drawOval(bodyRect, Paint()..color = hasFlash ? Colors.white : Colors.black54..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // 3. Vacuolas biológicas internas en flotación
    if (!hasFlash) {
      final Paint vacPaint = Paint()..color = (isRage ? Colors.orange : Colors.greenAccent).withAlpha(45);
      final double vac1X = cos(timeMs * 0.003) * half * 0.22;
      final double vac1Y = sin(timeMs * 0.004) * half * 0.22;
      final double vac2X = sin(timeMs * 0.005) * half * 0.25;
      final double vac2Y = cos(timeMs * 0.002) * half * 0.20;
      
      canvas.drawCircle(Offset(vac1X, vac1Y), half * 0.12, vacPaint);
      canvas.drawCircle(Offset(vac2X, vac2Y), half * 0.08, vacPaint);

      // Núcleo brillante
      final Paint corePaint = Paint()
        ..shader = RadialGradient(
          colors: [Colors.white, (isRage ? Colors.yellow : Colors.yellowAccent).withAlpha(140), Colors.transparent],
        ).createShader(Rect.fromCircle(center: const Offset(-8, -10), radius: half * 0.3));
      canvas.drawCircle(const Offset(-8, -10), half * 0.25, corePaint);
    }

    // 4. Ojos de enojo
    final double eyeOffset = half * 0.22;
    final Paint eyeBg = Paint()..color = hasFlash ? Colors.white : Colors.red[900]!;
    final Paint pupil = Paint()..color = hasFlash ? Colors.white : Colors.black;
    final Paint reflect = Paint()..color = Colors.white;

    canvas.drawOval(Rect.fromCenter(center: Offset(-eyeOffset, -6), width: 13, height: 16), eyeBg);
    canvas.drawOval(Rect.fromCenter(center: Offset(-eyeOffset + 1.5, -4), width: 6, height: 9), pupil);
    canvas.drawCircle(Offset(-eyeOffset + 0.5, -6), 1.8, reflect);

    canvas.drawOval(Rect.fromCenter(center: Offset(eyeOffset, -6), width: 13, height: 16), eyeBg);
    canvas.drawOval(Rect.fromCenter(center: Offset(eyeOffset - 1.5, -4), width: 6, height: 9), pupil);
    canvas.drawCircle(Offset(eyeOffset - 2.5, -6), 1.8, reflect);

    // Cejas enojadas
    final Paint browPaint = Paint()
      ..color = hasFlash ? Colors.white : Colors.black
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(-eyeOffset - 9, -15), Offset(-eyeOffset + 3, -9), browPaint);
    canvas.drawLine(Offset(eyeOffset + 9, -15), Offset(eyeOffset - 3, -9), browPaint);

    // 5. Boca monstruosa de enojo con dientes
    final mouthPath = Path();
    mouthPath.moveTo(-half * 0.22, half * 0.18);
    mouthPath.quadraticBezierTo(0, half * 0.38, half * 0.22, half * 0.18);
    mouthPath.quadraticBezierTo(0, half * 0.20, -half * 0.22, half * 0.18);
    mouthPath.close();
    canvas.drawPath(mouthPath, Paint()..color = hasFlash ? Colors.white : Colors.black);

    // Colmillos afilados
    if (!hasFlash) {
      final teethPaint = Paint()..color = Colors.white..style = PaintingStyle.fill;
      final t1 = Path()..moveTo(-half * 0.16, half * 0.20)..lineTo(-half * 0.11, half * 0.28)..lineTo(-half * 0.06, half * 0.21)..close();
      final t2 = Path()..moveTo(half * 0.06, half * 0.21)..lineTo(half * 0.11, half * 0.28)..lineTo(half * 0.16, half * 0.20)..close();
      canvas.drawPath(t1, teethPaint);
      canvas.drawPath(t2, teethPaint);
      
      // Baba ácida goteando
      final double dropTime = (timeMs * 0.003) % 1.0;
      final double dropY = half * 0.26 + dropTime * half * 0.24;
      final double dropAlpha = (1.0 - dropTime).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(0, dropY),
        1.8,
        Paint()..color = Colors.lightGreenAccent.withAlpha((dropAlpha * 255).toInt()),
      );
    }
  }

  static void _drawAmebaMutante(Canvas canvas, double half, int timeMs, bool isRage, bool hasFlash) {
    // 1. Preparar degradados y pinturas translúcidas multicromáticas
    final Paint bodyPaint = Paint()
      ..style = PaintingStyle.fill;
    
    final Rect bodyRect = Rect.fromCircle(center: Offset.zero, radius: half * 0.85);

    if (hasFlash) {
      bodyPaint.color = Colors.white;
    } else {
      bodyPaint.shader = RadialGradient(
        colors: isRage 
            ? [const Color(0xFFFF2E93), const Color(0xFFFF8A00), const Color(0xFF3A0066)] 
            : [const Color(0xFFE040FB), const Color(0xFF00E5FF), const Color(0xFF4A148C)],
        stops: const [0.1, 0.65, 1.0],
        center: const Alignment(-0.2, -0.2),
      ).createShader(bodyRect);
    }

    // 2. Generar pseudópodos dinámicos y orgánicos con curvas Bézier
    final Path amebaPath = Path();
    const int wavePoints = 12;
    final double baseRadius = half * 0.62;

    for (int i = 0; i <= wavePoints; i++) {
      final double angle = (i * 2 * pi) / wavePoints;
      final double waveVal = sin(timeMs * 0.005 + i * 1.8) * 9.0 + cos(timeMs * 0.007 - i * 0.8) * 4.0;
      final double currentRadius = baseRadius + waveVal;
      final double x = cos(angle) * currentRadius;
      final double y = sin(angle) * currentRadius;

      if (i == 0) {
        amebaPath.moveTo(x, y);
      } else {
        final double prevAngle = ((i - 1) * 2 * pi) / wavePoints;
        final double cpAngle = prevAngle + (pi / wavePoints);
        final double cpRadius = baseRadius + 14 + sin(timeMs * 0.006 + (i - 0.5) * 2.2) * 8.0;
        final double cpX = cos(cpAngle) * cpRadius;
        final double cpY = sin(cpAngle) * cpRadius;

        amebaPath.quadraticBezierTo(cpX, cpY, x, y);
      }
    }
    amebaPath.close();

    // Dibujar cuerpo principal con leve transparencia
    canvas.save();
    if (!hasFlash) {
      // Brillo/Glow del cuerpo en el fondo
      final Paint glowPaint = Paint()
        ..color = (isRage ? Colors.orangeAccent : Colors.cyanAccent).withAlpha(60)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawPath(amebaPath, glowPaint);
    }
    canvas.drawPath(amebaPath, bodyPaint);
    canvas.drawPath(amebaPath, Paint()..color = hasFlash ? Colors.white : Colors.white24..style = PaintingStyle.stroke..strokeWidth = 1.0);

    // 3. Dibujar Capa Citoplasmática Interna con efecto de refracción
    if (!hasFlash) {
      final Paint innerPaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
          colors: [Colors.white.withAlpha(90), Colors.transparent],
          stops: const [0.0, 0.8],
        ).createShader(Rect.fromCircle(center: const Offset(-10, -10), radius: half * 0.5));
      canvas.drawPath(amebaPath, innerPaint);
    }

    // 4. Bi-núcleo flotante interconectado por filamentos
    if (!hasFlash) {
      final double n1X = cos(timeMs * 0.004) * half * 0.24;
      final double n1Y = sin(timeMs * 0.005) * half * 0.24 - half * 0.2;
      final double n2X = sin(timeMs * 0.003 + 2.0) * half * 0.26;
      final double n2Y = cos(timeMs * 0.004 + 2.0) * half * 0.20 + half * 0.2;

      // Filamento de conexión
      final Paint filPaint = Paint()
        ..color = Colors.white.withAlpha(90)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(n1X, n1Y), Offset(n2X, n2Y), filPaint);

      // Núcleos transparentes brillantes
      final Paint n1Paint = Paint()
        ..shader = RadialGradient(
          colors: [Colors.white, (isRage ? Colors.redAccent : Colors.purpleAccent).withAlpha(160), Colors.transparent],
        ).createShader(Rect.fromCircle(center: Offset(n1X - 2, n1Y - 2), radius: 8));
      final Paint n2Paint = Paint()
        ..shader = RadialGradient(
          colors: [Colors.white, (isRage ? Colors.yellowAccent : Colors.cyanAccent).withAlpha(160), Colors.transparent],
        ).createShader(Rect.fromCircle(center: Offset(n2X - 2, n2Y - 2), radius: 6));

      canvas.drawCircle(Offset(n1X, n1Y), 8.0, n1Paint);
      canvas.drawCircle(Offset(n2X, n2Y), 6.0, n2Paint);
      
      // Vacuolas
      final Paint vacPaint = Paint()..color = Colors.white.withAlpha(40);
      canvas.drawCircle(Offset(-half * 0.35, half * 0.35), 7, vacPaint);
      canvas.drawCircle(Offset(half * 0.4, -half * 0.3), 5, vacPaint);
    }
    canvas.restore();

    // 5. Ojo Cíclope interactivo con ciclo de parpadeo (blink) y párpados arrugados
    // Calcular factor de parpadeo
    double blinkFactor = 1.0;
    final int cycle = timeMs % 3500;
    if (cycle > 3300) {
      final double t = (cycle - 3300) / 200.0;
      blinkFactor = (sin(t * pi) - 1.0).abs();
    }

    final double eyeRad = half * 0.28;
    
    // Dibujar esclerótica con volumen esférico
    final Paint eyeBg = Paint()
      ..style = PaintingStyle.fill
      ..shader = const RadialGradient(
        colors: [Colors.white, Color(0xFFE2E8F0)],
        stops: [0.6, 1.0],
        center: Alignment(-0.25, -0.25),
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: eyeRad));
    
    canvas.save();
    canvas.scale(1.0, blinkFactor); // Escalar verticalmente para el parpadeo

    canvas.drawCircle(Offset.zero, eyeRad, hasFlash ? (Paint()..color = Colors.white) : eyeBg);
    canvas.drawCircle(Offset.zero, eyeRad, Paint()..color = hasFlash ? Colors.white : Colors.black..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // Iris detallado
    final Paint iris = Paint()
      ..shader = RadialGradient(
        colors: isRage 
            ? [Colors.yellowAccent, const Color(0xFFFF0055), const Color(0xFF4A0000)] 
            : [Colors.cyanAccent, const Color(0xFF0022FF), const Color(0xFF00032C)],
        stops: const [0.15, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: eyeRad * 0.78));
    canvas.drawCircle(Offset.zero, eyeRad * 0.76, hasFlash ? (Paint()..color = Colors.white) : iris);

    // Pupila vertical de gato/monstruo
    final Paint pupil = Paint()..color = hasFlash ? Colors.white : Colors.black;
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: eyeRad * 0.28, height: eyeRad * 0.64), pupil);

    // Brillos de luz realistas en la córnea
    if (!hasFlash) {
      canvas.drawCircle(const Offset(-4, -5), 3.5, Paint()..color = Colors.white);
      canvas.drawCircle(const Offset(3, 4), 1.5, Paint()..color = Colors.white.withAlpha(180));
    }
    canvas.restore();

    // Dibujar párpados de ameba arrugados arriba y abajo
    if (!hasFlash) {
      final Paint lidPaint = Paint()
        ..color = isRage ? const Color(0xFF4A0000) : const Color(0xFF310B5E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;

      final double lidCurveY = eyeRad * (1.0 - blinkFactor);
      
      // Párpado superior
      final Path topLid = Path()
        ..moveTo(-eyeRad * 1.15, -eyeRad * 0.3 + lidCurveY)
        ..quadraticBezierTo(0, -eyeRad * 1.3 + lidCurveY * 0.5, eyeRad * 1.15, -eyeRad * 0.3 + lidCurveY);
      canvas.drawPath(topLid, lidPaint);

      // Párpado inferior
      final Path botLid = Path()
        ..moveTo(-eyeRad * 1.15, eyeRad * 0.3 - lidCurveY)
        ..quadraticBezierTo(0, eyeRad * 1.3 - lidCurveY * 0.5, eyeRad * 1.15, eyeRad * 0.3 - lidCurveY);
      canvas.drawPath(botLid, lidPaint);
    }
  }

  static void _drawGermenGigante(Canvas canvas, double half, int timeMs, bool isRage, bool hasFlash) {
    final double radius = half * 0.56;

    // 1. Espículas (Spikes proteicos) cónicas con relieves y esferas de energía pulsantes
    const int spikeCount = 12;
    for (int i = 0; i < spikeCount; i++) {
      // Rotar las espículas lentamente con el tiempo
      final double angle = (i * 2 * pi) / spikeCount + (timeMs * 0.0007);
      final double pulse = sin(timeMs * 0.010 + i * 1.5) * 5.0;
      
      const double baseWidth = 8.0;
      final double startDist = radius * 0.4;
      final double endDist = radius * 1.32 + pulse;

      final double cosA = cos(angle);
      final double sinA = sin(angle);
      
      final double startX = cosA * startDist;
      final double startY = sinA * startDist;
      final double endX = cosA * endDist;
      final double endY = sinA * endDist;

      // Dibujar cono / relieve de la espícula
      final Path spikePath = Path();
      // Dibujar base del cono
      final double perpX = -sinA * (baseWidth / 2);
      final double perpY = cosA * (baseWidth / 2);
      
      spikePath.moveTo(startX + perpX, startY + perpY);
      spikePath.lineTo(startX - perpX, startY - perpY);
      spikePath.lineTo(endX, endY);
      spikePath.close();

      final Paint spikePaint = Paint()
        ..style = PaintingStyle.fill;
        
      if (hasFlash) {
        spikePaint.color = Colors.white;
      } else {
        spikePaint.shader = LinearGradient(
          colors: isRage 
              ? [Colors.redAccent, const Color(0xFFD35400), const Color(0xFF5F0000)]
              : [Colors.lightGreenAccent, Colors.green[700]!, const Color(0xFF0F2B03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromPoints(Offset(startX, startY), Offset(endX, endY)));
      }
      
      canvas.drawPath(spikePath, spikePaint);
      canvas.drawPath(spikePath, Paint()..color = hasFlash ? Colors.white : Colors.black26..style = PaintingStyle.stroke..strokeWidth = 0.8);

      // Anillo de relieve intermedio
      final double midX = cosA * (startDist + (endDist - startDist) * 0.5);
      final double midY = sinA * (startDist + (endDist - startDist) * 0.5);
      canvas.drawCircle(
        Offset(midX, midY),
        3.5,
        Paint()..color = hasFlash ? Colors.white : (isRage ? Colors.orangeAccent : Colors.greenAccent)..style = PaintingStyle.stroke..strokeWidth = 1.0,
      );

      // Esferas terminales de energía cristalina con brillo radial
      final Paint tipPaint = Paint()
        ..shader = RadialGradient(
          colors: hasFlash 
              ? [Colors.white, Colors.white]
              : [Colors.white, isRage ? Colors.yellowAccent : Colors.orangeAccent, Colors.transparent],
        ).createShader(Rect.fromCircle(center: Offset(endX, endY), radius: 8.5));
      canvas.drawCircle(Offset(endX, endY), 8.0, tipPaint);
    }

    // 2. Cuerpo esférico central con textura y relieve de gradiente radial
    final Paint bodyPaint = Paint()..style = PaintingStyle.fill;
    final Rect bodyRect = Rect.fromCircle(center: Offset.zero, radius: radius);
    if (hasFlash) {
      bodyPaint.color = Colors.white;
    } else {
      bodyPaint.shader = RadialGradient(
        colors: isRage 
            ? [const Color(0xFFFF5722), const Color(0xFFD84315), const Color(0xFF3E0A00)]
            : [Colors.greenAccent[400]!, const Color(0xFF2E7D32), const Color(0xFF0C290E)],
        stops: const [0.1, 0.6, 1.0],
        center: const Alignment(-0.25, -0.25),
      ).createShader(bodyRect);
    }
    canvas.drawCircle(Offset.zero, radius, bodyPaint);
    canvas.drawCircle(Offset.zero, radius, Paint()..color = hasFlash ? Colors.white : Colors.black54..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // 3. Cráteres sombreados 3D sobre la superficie
    if (!hasFlash) {
      const List<Offset> craters = [
        Offset(-14, 15),
        Offset(16, 12),
        Offset(-2, -18),
      ];
      const List<double> craterRadii = [7.5, 6.0, 5.0];

      for (int i = 0; i < craters.length; i++) {
        final double cx = craters[i].dx;
        final double cy = craters[i].dy;
        final double crRad = craterRadii[i];
        
        final Paint craterPaint = Paint()
          ..shader = RadialGradient(
            colors: isRage 
                ? [const Color(0xFF3A0000), const Color(0xFFD84315).withAlpha(100)]
                : [const Color(0xFF081F03), const Color(0xFF2E7D32).withAlpha(100)],
            center: const Alignment(0.3, 0.3),
          ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: crRad));
        
        canvas.drawCircle(Offset(cx, cy), crRad, craterPaint);
        
        // Borde superior iluminado del cráter
        canvas.drawCircle(
          Offset(cx, cy),
          crRad,
          Paint()
            ..color = isRage ? Colors.orangeAccent.withAlpha(120) : Colors.lightGreenAccent.withAlpha(120)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );
      }

      // Gas tóxico o humo flotante vectorial saliendo de los cráteres
      final double gasTime = (timeMs * 0.002) % 1.0;
      final double gasAlpha = (1.0 - gasTime).clamp(0.0, 1.0);
      final Paint gasPaint = Paint()
        ..color = (isRage ? Colors.orangeAccent : Colors.lightGreenAccent).withAlpha((gasAlpha * 110).toInt())
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      
      canvas.drawCircle(Offset(-14, 15 - gasTime * 15.0), 4.5 + gasTime * 6, gasPaint);
      canvas.drawCircle(Offset(16, 12 - gasTime * 12.0), 3.5 + gasTime * 5, gasPaint);
    }

    // 4. Tres Ojos Dementes asimétricos e inyectados en sangre
    const List<Offset> eyeOffsets = [
      Offset(-12, -8),  // Ojo izquierdo (Grande)
      Offset(12, -12),  // Ojo derecho (Medio)
      Offset(2, 6),    // Ojo inferior (Pequeño)
    ];
    const List<double> eyeRadii = [10.5, 7.5, 5.5];

    final Paint eyeBg = Paint()..color = Colors.white;
    final Paint capilarPaint = Paint()
      ..color = Colors.red.withAlpha(200)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < eyeOffsets.length; i++) {
      final Offset offset = eyeOffsets[i];
      final double rad = eyeRadii[i];

      // Dibujar esclerótica
      canvas.drawCircle(offset, rad, eyeBg);
      canvas.drawCircle(offset, rad, Paint()..color = hasFlash ? Colors.white : Colors.black87..style = PaintingStyle.stroke..strokeWidth = 1.2);

      // Dibujar capilares rojos (locura)
      if (!hasFlash) {
        canvas.drawLine(offset - Offset(rad * 0.8, 0), offset - Offset(rad * 0.2, 0), capilarPaint);
        canvas.drawLine(offset + Offset(rad * 0.5, -rad * 0.5), offset + Offset(rad * 0.1, -rad * 0.1), capilarPaint);
        canvas.drawLine(offset + Offset(0, rad * 0.7), offset + Offset(0, rad * 0.2), capilarPaint);
      }

      // Calcular temblor de pupila (locura/ira)
      final double jitterX = sin(timeMs * 0.06 + i) * 1.2;
      final double jitterY = cos(timeMs * 0.05 + i * 2) * 1.2;
      final Offset pupilOffset = offset + Offset(jitterX, jitterY);

      // Pupila
      canvas.drawCircle(pupilOffset, rad * 0.55, hasFlash ? (Paint()..color = Colors.white) : (Paint()..color = Colors.black));

      // Brillo corneal
      if (!hasFlash) {
        canvas.drawCircle(pupilOffset - Offset(rad * 0.15, rad * 0.15), 1.8, Paint()..color = Colors.white);
      }
    }
  }

  static void _drawVirusSupremo(Canvas canvas, double half, int timeMs, bool isRage, bool hasFlash) {
    // 1. Patas robóticas articuladas con ciclo de crawling animado (cinemática 2D)
    final Paint legPaint = Paint()
      ..color = hasFlash ? Colors.white : const Color(0xFF475569)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Paint jointPaint = Paint()
      ..color = hasFlash ? Colors.white : const Color(0xFF94A3B8)
      ..style = PaintingStyle.fill;

    final double groundY = half * 0.85;

    // Dibujar 4 patas mecánicas con articulación fémur-tibia-garra
    for (int i = 0; i < 4; i++) {
      final bool isLeft = i % 2 == 0;
      final bool isFront = i < 2;
      
      final double legSign = isLeft ? -1.0 : 1.0;
      // Desfase de animación para simular caminata coordinada
      final double stepOffset = isFront ? 0.0 : pi;
      final double cycleMove = sin(timeMs * 0.01 + stepOffset) * 8.0;
      
      final double hipX = legSign * 4.0;
      final double hipY = half * 0.35;
      
      final double kneeX = legSign * (half * (isFront ? 0.35 : 0.25)) + cycleMove;
      final double kneeY = half * 0.55 + (isFront ? cycleMove * 0.3 : -cycleMove * 0.3);
      
      final double footX = legSign * (half * (isFront ? 0.65 : 0.45)) + cycleMove * 1.5;
      final double footY = groundY + (isFront ? sin(timeMs * 0.01 + stepOffset).clamp(0.0, 1.0) * -4.0 : 0.0);

      // Dibujar segmentos de la pata
      canvas.drawLine(Offset(hipX, hipY), Offset(kneeX, kneeY), legPaint);
      canvas.drawLine(Offset(kneeX, kneeY), Offset(footX, footY), legPaint);
      
      // Dibujar garra terminal
      final Path claw = Path()
        ..moveTo(footX, footY)
        ..lineTo(footX - legSign * 5, footY + 4)
        ..lineTo(footX + legSign * 3, footY + 4);
      canvas.drawPath(claw, legPaint);

      // Dibujar articulaciones de perno
      if (!hasFlash) {
        canvas.drawCircle(Offset(kneeX, kneeY), 3.0, jointPaint);
        canvas.drawCircle(Offset(kneeX, kneeY), 3.0, Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 0.5);
      }
    }

    // 2. Collar y cuello helicoidal (Vaina de resorte comprimible)
    final double compress = 1.0 + 0.06 * sin(timeMs * 0.016);
    final double sheathHeight = half * 0.42 * compress;
    
    // Collar superior e inferior
    final Paint collarPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF1E293B), Color(0xFF64748B), Color(0xFF0F172A)],
      ).createShader(Rect.fromLTWH(-half * 0.2, 5, half * 0.4, sheathHeight));
      
    canvas.drawRect(Rect.fromLTWH(-half * 0.2, 3, half * 0.4, 4), collarPaint);
    canvas.drawRect(Rect.fromLTWH(-half * 0.2, 3, half * 0.4, 4), Paint()..color = hasFlash ? Colors.white : Colors.black45..style = PaintingStyle.stroke..strokeWidth = 0.8);
    
    // Espirales del cuello
    const int turns = 5;
    for (int j = 0; j < turns; j++) {
      final double currY = 7 + (sheathHeight / turns) * j;
      final double widthVal = half * 0.28 - (j * 1.5);
      
      final Rect turnRect = Rect.fromCenter(center: Offset(0, currY), width: widthVal, height: 4.5);
      canvas.drawOval(turnRect, collarPaint);
      canvas.drawOval(turnRect, Paint()..color = hasFlash ? Colors.white : Colors.black38..style = PaintingStyle.stroke..strokeWidth = 0.6);
    }
    
    canvas.drawRect(Rect.fromLTWH(-half * 0.16, 7 + sheathHeight, half * 0.32, 4), collarPaint);

    // 3. Cabeza geométrica 3D de Icosaedro facetado con iluminación reactiva
    final double headRadius = half * 0.58;
    final double headY = -half * 0.28;
    final double cY = headY;
    
    final pTop = Offset(0, cY - headRadius);
    final pBottom = Offset(0, cY + headRadius * 0.7);
    final pLeftMid = Offset(-headRadius, cY - headRadius * 0.15);
    final pRightMid = Offset(headRadius, cY - headRadius * 0.15);
    final pLeftTop = Offset(-headRadius * 0.65, cY - headRadius * 0.75);
    final pRightTop = Offset(headRadius * 0.65, cY - headRadius * 0.75);
    final pLeftBottom = Offset(-headRadius * 0.65, cY + headRadius * 0.55);
    final pRightBottom = Offset(headRadius * 0.65, cY + headRadius * 0.55);
    final pCenter = Offset(0, cY - headRadius * 0.05);

    final List<Path> faces = [];
    faces.add(Path()..moveTo(pTop.dx, pTop.dy)..lineTo(pLeftTop.dx, pLeftTop.dy)..lineTo(pCenter.dx, pCenter.dy)..close());
    faces.add(Path()..moveTo(pTop.dx, pTop.dy)..lineTo(pRightTop.dx, pRightTop.dy)..lineTo(pCenter.dx, pCenter.dy)..close());
    faces.add(Path()..moveTo(pLeftTop.dx, pLeftTop.dy)..lineTo(pLeftMid.dx, pLeftMid.dy)..lineTo(pCenter.dx, pCenter.dy)..close());
    faces.add(Path()..moveTo(pRightTop.dx, pRightTop.dy)..lineTo(pRightMid.dx, pRightMid.dy)..lineTo(pCenter.dx, pCenter.dy)..close());
    faces.add(Path()..moveTo(pLeftMid.dx, pLeftMid.dy)..lineTo(pLeftBottom.dx, pLeftBottom.dy)..lineTo(pCenter.dx, pCenter.dy)..close());
    faces.add(Path()..moveTo(pRightMid.dx, pRightMid.dy)..lineTo(pRightBottom.dx, pRightBottom.dy)..lineTo(pCenter.dx, pCenter.dy)..close());
    faces.add(Path()..moveTo(pLeftBottom.dx, pLeftBottom.dy)..lineTo(pBottom.dx, pBottom.dy)..lineTo(pCenter.dx, pCenter.dy)..close());
    faces.add(Path()..moveTo(pRightBottom.dx, pRightBottom.dy)..lineTo(pBottom.dx, pBottom.dy)..lineTo(pCenter.dx, pCenter.dy)..close());

    final List<Color> baseColors = isRage 
        ? [
            Colors.orange[900]!, 
            Colors.deepOrange[700]!, 
            Colors.red[800]!, 
            Colors.orange[600]!, 
            Colors.amber[800]!, 
            Colors.red[900]!,
            Colors.orange[800]!,
            Colors.red[700]!
          ]
        : [
            const Color(0xFF3B0066), 
            const Color(0xFF530099), 
            const Color(0xFF6B00CC), 
            const Color(0xFF00B3CC), 
            const Color(0xFF00E5FF), 
            const Color(0xFF8800CC),
            const Color(0xFF0D47A1),
            const Color(0xFF1E88E5),
          ];

    // Iluminación dinámica facetada basada en un balanceo virtual de luz
    final double lightAngle = sin(timeMs * 0.005) * 0.6;

    for (int i = 0; i < faces.length; i++) {
      final Paint facePaint = Paint()..style = PaintingStyle.fill;
      if (hasFlash) {
        facePaint.color = Colors.white;
      } else {
        // Calcular el factor de luz en base a la faceta y el ángulo del brillo
        final double angleFactor = cos(lightAngle + i * (2 * pi / faces.length));
        Color col = baseColors[i % baseColors.length];
        
        // Mezclar sombreado e iluminación especular en 3D
        col = Color.lerp(col, Colors.white, (angleFactor * 0.22).clamp(0.0, 0.22))!;
        col = Color.lerp(col, Colors.black, (-angleFactor * 0.28).clamp(0.0, 0.28))!;
        facePaint.color = col;
      }
      canvas.drawPath(faces[i], facePaint);
      canvas.drawPath(faces[i], Paint()..color = hasFlash ? Colors.white : Colors.white24..style = PaintingStyle.stroke..strokeWidth = 0.8);
    }

    // 4. Reactor central neón con aspas de plasma rotatorias
    if (!hasFlash) {
      final Paint radPaint = Paint()
        ..color = isRage ? Colors.yellowAccent : Colors.cyanAccent
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4.5);
      canvas.drawCircle(pCenter, 8.5, radPaint);

      // Aspas rotatorias del reactor
      final double rotAngle = timeMs * 0.003;
      final Paint bladePaint = Paint()
        ..color = Colors.black87
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      for (int k = 0; k < 3; k++) {
        final double a = rotAngle + k * (2 * pi / 3);
        canvas.drawLine(pCenter, pCenter + Offset(cos(a) * 7.5, sin(a) * 7.5), bladePaint);
      }
      canvas.drawCircle(pCenter, 2.5, Paint()..color = isRage ? Colors.orange : Colors.blueAccent);
    }

    // 5. Corona Real Dorada premium con gemas y Anillos Electromagnéticos flotantes
    final double floatOffset = sin(timeMs * 0.007) * 4.0;
    final double crownY = pTop.dy - 13 + floatOffset;

    // Anillos electromagnéticos translúcidos alrededor de la corona
    if (!hasFlash) {
      final Paint ringPaint = Paint()
        ..color = (isRage ? Colors.orangeAccent : Colors.cyanAccent).withAlpha(120)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 1.5);
      canvas.save();
      canvas.translate(0, crownY - 5);
      canvas.rotate(0.25);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: half * 0.8, height: 5), ringPaint);
      canvas.rotate(-0.5);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: half * 0.8, height: 5), ringPaint);
      canvas.restore();
    }

    final Paint crownPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFFFD700), // Oro
          Color(0xFFFFA000), // Oro medio
          Color(0xFFE65100), // Oro oscuro
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(-half * 0.35, crownY - 14, half * 0.7, 18));

    final crownPath = Path();
    crownPath.moveTo(-half * 0.32, crownY);
    crownPath.lineTo(-half * 0.36, crownY - 13);
    crownPath.lineTo(-half * 0.14, crownY - 6);
    crownPath.lineTo(0, crownY - 18);
    crownPath.lineTo(half * 0.14, crownY - 6);
    crownPath.lineTo(half * 0.36, crownY - 13);
    crownPath.lineTo(half * 0.32, crownY);
    crownPath.close();

    canvas.drawPath(crownPath, hasFlash ? (Paint()..color = Colors.white) : crownPaint);
    canvas.drawPath(crownPath, Paint()..color = hasFlash ? Colors.white : const Color(0xFF6D4C41)..style = PaintingStyle.stroke..strokeWidth = 0.6);

    // Perlas y gemas facetadas
    final Paint pearl = Paint()..color = const Color(0xFFFFFDE7);
    canvas.drawCircle(Offset(-half * 0.36, crownY - 13), 2.2, hasFlash ? (Paint()..color = Colors.white) : pearl);
    canvas.drawCircle(Offset(0, crownY - 18), 2.8, hasFlash ? (Paint()..color = Colors.white) : pearl);
    canvas.drawCircle(Offset(half * 0.36, crownY - 13), 2.2, hasFlash ? (Paint()..color = Colors.white) : pearl);

    // Gema de rubí central
    if (!hasFlash) {
      canvas.drawCircle(Offset(0, crownY - 7), 1.8, Paint()..color = Colors.redAccent);
    }
  }
}
