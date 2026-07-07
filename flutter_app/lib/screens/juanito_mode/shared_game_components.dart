import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame_audio/flame_audio.dart';
import '../juanito_mode_screen.dart';

/// SFX de los minijuegos sobre AudioPools reutilizables: FlameAudio.play
/// instancia y desecha un AudioPlayer nativo por llamada, y a 3-7 efectos/s
/// (disparos, monedas, saltos) eso produce churn de GC y microparones en
/// Android. Los pools se crean una vez al precargar el Modo Juanito ([init]).
class GameAudio {
  static final Map<String, AudioPool> _pools = {};
  static Future<void>? _initFuture;

  static Future<void> init() {
    return _initFuture ??= _createPools();
  }

  static Future<void> _createPools() async {
    // maxPlayers según cadencia máxima de cada efecto en partida
    const maxPlayersPerSfx = {
      'shoot.wav': 3,
      'explosion.wav': 2,
      'hit.wav': 2,
      'coin.wav': 3,
      'jump.wav': 3,
    };
    for (final entry in maxPlayersPerSfx.entries) {
      try {
        _pools[entry.key] = await FlameAudio.createPool(entry.key, maxPlayers: entry.value);
      } catch (e) {
        // Sin pool, play() cae al FlameAudio.play de siempre; no es crítico.
        debugPrint('Error creando AudioPool de ${entry.key}: $e');
      }
    }
  }

  static void play(String file, {double volume = 1.0}) {
    if (JuanitoModeScreen.isMuted) return;
    // Si queremos reducir el volumen de Poop Invaders de forma nativa:
    final double volMultiplier = (file == 'shoot.wav' || file == 'explosion.wav') ? 0.35 : 1.0;
    final pool = _pools[file];
    if (pool != null) {
      pool.start(volume: volume * volMultiplier);
    } else {
      FlameAudio.play(file, volume: volume * volMultiplier);
    }
  }
}

/// Texto flotante de feedback («+10», «¡NIVEL 2!»…) compartido por los cuatro
/// minijuegos. El texto es inmutable: se rasteriza UNA vez en onLoad y el
/// desvanecido se aplica con el alpha del Paint al dibujar la textura.
/// Re-layoutear el TextPainter cada frame solo para cambiar el alpha era caro
/// (shaping de texto con emoji) y además inútil: los glifos emoji de color
/// ignoran el fill de TextStyle, así que el fade ni siquiera se veía.
/// [wobble] añade la rotación aleatoria y el «pop» de escala de Poop Invaders.
class FloatingTextComponent extends PositionComponent {
  final String text;
  final Color color;
  final double fontSize;
  final bool wobble;

  double life = 1.0;
  double _targetAngle = 0.0;
  ui.Image? _image;

  // Margen para que la sombra del texto no quede recortada al rasterizar
  static const double _pad = 8.0;
  static const double _rasterScale = 2.0;

  FloatingTextComponent({
    required this.text,
    required this.color,
    required this.fontSize,
    this.wobble = false,
  }) {
    anchor = Anchor.center;
    if (wobble) {
      _targetAngle = (Random().nextDouble() - 0.5) * 0.3;
      angle = _targetAngle;
    }
  }

  @override
  void onLoad() {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          shadows: const [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1))],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final width = (textPainter.width + _pad * 2) * _rasterScale;
    final height = (textPainter.height + _pad * 2) * _rasterScale;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));
    canvas.scale(_rasterScale);
    textPainter.paint(canvas, const Offset(_pad, _pad));
    final picture = recorder.endRecording();
    _image = picture.toImageSync(max(1, width.ceil()), max(1, height.ceil()));
    picture.dispose();
  }

  @override
  void onRemove() {
    // Textura por instancia (el texto varía): sí se libera al desaparecer
    _image?.dispose();
    _image = null;
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);
    life -= dt;
    position.y -= dt * 50;

    if (wobble) {
      angle = ui.lerpDouble(angle, _targetAngle, dt * 5.0) ?? angle;
      final scaleVal = life > 0.8 ? 1.0 + (life - 0.8) * 1.8 : 1.0;
      scale = Vector2.all(scaleVal);
    }

    if (life <= 0) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final img = _image;
    if (img == null) return;
    final width = img.width / _rasterScale;
    final height = img.height / _rasterScale;
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromCenter(center: Offset.zero, width: width, height: height),
      Paint()
        ..color = Colors.white.withAlpha((life.clamp(0.0, 1.0) * 255).toInt())
        ..filterQuality = FilterQuality.low,
    );
  }
}

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
