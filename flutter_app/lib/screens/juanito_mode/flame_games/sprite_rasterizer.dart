import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Helper class to convert heavy vector canvas drawings into cached ui.Image textures
/// This eliminates CPU load during the render loop (60 FPS) and significantly improves battery life.
class SpriteRasterizer {
  static Future<ui.Image> rasterize(double width, double height, void Function(Canvas canvas) paintFn) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

    // Ejecutar el dibujado vectorial pesado en el lienzo de grabación
    paintFn(canvas);

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.ceil(), height.ceil());
    // El Picture es un recurso nativo: liberarlo tras rasterizar para no fugarlo
    // en cada llamada (se invoca por cada láser/enemigo/sprite del juego).
    picture.dispose();
    return image;
  }
}

/// Caché de texturas rasterizadas compartida por CLAVE de tipo (no por
/// instancia): cada láser/enemigo/jugador con la misma apariencia reutiliza la
/// misma ui.Image entre instancias y entre partidas, en vez de ejecutar
/// PictureRecorder → toImage en cada onLoad. La limpieza es única, al salir
/// del Modo Juanito ([clear]), sustituyendo a los dispose por componente.
class SpriteCache {
  static final Map<String, Future<ui.Image>> _cache = {};

  static Future<ui.Image> getOrCreate(
    String key,
    double width,
    double height,
    void Function(Canvas canvas) paintFn,
  ) {
    return _cache.putIfAbsent(key, () => SpriteRasterizer.rasterize(width, height, paintFn));
  }

  /// Libera todas las texturas; llamar solo al salir del Modo Juanito.
  static Future<void> clear() async {
    final pending = _cache.values.toList();
    _cache.clear();
    for (final future in pending) {
      try {
        (await future).dispose();
      } catch (_) {
        // Si la rasterización falló, no hay textura que liberar.
      }
    }
  }
}

/// Caché estática de emojis rasterizados (clave: emoji+tamaño). Dibujar un
/// emoji con TextPainter implica construir y layoutear el texto en cada frame;
/// con decenas de partículas vivas era el mayor coste de CPU de los
/// minijuegos. Aquí cada glifo se rasteriza UNA vez (a 3x para que no se vea
/// borroso en pantallas densas) y después solo se hace drawImageRect. El alpha
/// del Paint permite además el desvanecido, que vía TextStyle(color:) los
/// glifos emoji de color ignoraban.
class EmojiSprites {
  static const double _rasterScale = 3.0;
  static final Map<String, ui.Image> _cache = {};

  static ui.Image _get(String emoji, double fontSize) {
    return _cache.putIfAbsent('$emoji@$fontSize', () {
      final textPainter = TextPainter(
        text: TextSpan(text: emoji, style: TextStyle(fontSize: fontSize)),
        textDirection: TextDirection.ltr,
      )..layout();
      final width = textPainter.width * _rasterScale;
      final height = textPainter.height * _rasterScale;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));
      canvas.scale(_rasterScale);
      textPainter.paint(canvas, Offset.zero);
      final picture = recorder.endRecording();
      final image = picture.toImageSync(max(1, width.ceil()), max(1, height.ceil()));
      picture.dispose();
      return image;
    });
  }

  /// Dibuja [emoji] centrado en [center] con opacidad [opacity] (0-1).
  static void draw(
    Canvas canvas,
    String emoji,
    double fontSize,
    Offset center, {
    double opacity = 1.0,
  }) {
    final image = _get(emoji, fontSize);
    final width = image.width / _rasterScale;
    final height = image.height / _rasterScale;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromCenter(center: center, width: width, height: height),
      Paint()
        ..color = Colors.white.withAlpha((opacity.clamp(0.0, 1.0) * 255).toInt())
        ..filterQuality = FilterQuality.low,
    );
  }

  /// Libera todas las texturas; llamar solo al salir del Modo Juanito.
  static void clear() {
    for (final image in _cache.values) {
      image.dispose();
    }
    _cache.clear();
  }
}
