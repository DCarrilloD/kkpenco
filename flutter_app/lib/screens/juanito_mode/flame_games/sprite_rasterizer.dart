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
