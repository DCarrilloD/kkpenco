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
    return await picture.toImage(width.ceil(), height.ceil());
  }
}
