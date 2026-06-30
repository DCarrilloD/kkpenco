package com.kkpenco.app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.*
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent

class PoopWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.poop_widget_layout)

            // Generar y asignar las imágenes dibujadas con Canvas nativo
            views.setImageViewBitmap(R.id.img_cabra, drawPoopIcon(context, "cabra"))
            views.setImageViewBitmap(R.id.img_espurruteo, drawPoopIcon(context, "espurruteo"))
            views.setImageViewBitmap(R.id.img_normal, drawPoopIcon(context, "normal"))
            views.setImageViewBitmap(R.id.img_jurasica, drawPoopIcon(context, "jurasica"))

            // Configurar los Intents para cada botón interactivo
            val cabraIntent = HomeWidgetBackgroundIntent.getBroadcast(
                context,
                Uri.parse("kkpenco://express?consistency=cabra")
            )
            views.setOnClickPendingIntent(R.id.btn_cabra, cabraIntent)

            val espurruteoIntent = HomeWidgetBackgroundIntent.getBroadcast(
                context,
                Uri.parse("kkpenco://express?consistency=espurruteo")
            )
            views.setOnClickPendingIntent(R.id.btn_espurruteo, espurruteoIntent)

            val normalIntent = HomeWidgetBackgroundIntent.getBroadcast(
                context,
                Uri.parse("kkpenco://express?consistency=normal")
            )
            views.setOnClickPendingIntent(R.id.btn_normal, normalIntent)

            val jurasicaIntent = HomeWidgetBackgroundIntent.getBroadcast(
                context,
                Uri.parse("kkpenco://express?consistency=jurasica")
            )
            views.setOnClickPendingIntent(R.id.btn_jurasica, jurasicaIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun drawPoopIcon(context: Context, consistency: String): Bitmap {
        val size = 128
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)

        when (consistency) {
            "cabra" -> {
                // Dibujar 4 bolitas de cabra (esferas 3D con degradado radial)
                val positions = arrayOf(
                    floatArrayOf(64f, 68f, 18f), // Central inferior
                    floatArrayOf(42f, 52f, 14f), // Izquierda
                    floatArrayOf(86f, 54f, 15f), // Derecha
                    floatArrayOf(62f, 38f, 13f)  // Superior
                )
                for (pos in positions) {
                    val cx = pos[0]
                    val cy = pos[1]
                    val r = pos[2]
                    
                    val shader = RadialGradient(
                        cx - r/3f, cy - r/3f, r * 1.3f,
                        Color.parseColor("#A1887F"), // Luz marrón
                        Color.parseColor("#4E342E"), // Sombra oscura
                        Shader.TileMode.CLAMP
                    )
                    paint.shader = shader
                    canvas.drawCircle(cx, cy, r, paint)
                    paint.shader = null
                    
                    // Pequeño brillo superior izquierdo
                    paint.color = Color.parseColor("#D7CCC8")
                    paint.alpha = 80
                    canvas.drawCircle(cx - r/3f, cy - r/3f, r/4f, paint)
                    paint.alpha = 255
                }
            }
            "espurruteo" -> {
                // Gota central de agua con gradiente lineal y brillo
                val mainPath = Path()
                mainPath.moveTo(64f, 25f)
                mainPath.cubicTo(64f, 25f, 92f, 75f, 92f, 90f)
                mainPath.arcTo(RectF(36f, 62f, 92f, 118f), 0f, 180f, false)
                mainPath.cubicTo(36f, 75f, 64f, 25f, 64f, 25f)
                mainPath.close()

                val grad = LinearGradient(
                    64f, 25f, 64f, 100f,
                    Color.parseColor("#4FC3F7"), // Celeste
                    Color.parseColor("#1565C0"), // Azul oscuro
                    Shader.TileMode.CLAMP
                )
                paint.shader = grad
                canvas.drawPath(mainPath, paint)
                paint.shader = null

                // Reflejo de luz dentro de la gota
                paint.color = Color.WHITE
                paint.alpha = 100
                val shinePath = Path()
                shinePath.moveTo(60f, 40f)
                shinePath.cubicTo(60f, 40f, 78f, 72f, 78f, 85f)
                shinePath.cubicTo(78f, 87f, 75f, 88f, 73f, 85f)
                shinePath.cubicTo(73f, 72f, 58f, 43f, 58f, 40f)
                shinePath.close()
                canvas.drawPath(shinePath, paint)
                paint.alpha = 255

                // Gota izquierda pequeña salpicando
                val leftPath = Path()
                leftPath.moveTo(30f, 55f)
                leftPath.cubicTo(30f, 55f, 42f, 75f, 38f, 82f)
                leftPath.arcTo(RectF(18f, 68f, 38f, 88f), -30f, 180f, false)
                leftPath.cubicTo(18f, 75f, 30f, 55f, 30f, 55f)
                leftPath.close()
                
                paint.color = Color.parseColor("#29B6F6")
                canvas.drawPath(leftPath, paint)

                // Gota derecha pequeña salpicando
                val rightPath = Path()
                rightPath.moveTo(98f, 55f)
                rightPath.cubicTo(98f, 55f, 110f, 75f, 106f, 82f)
                rightPath.arcTo(RectF(88f, 68f, 108f, 88f), -30f, 180f, false)
                rightPath.cubicTo(88f, 75f, 98f, 55f, 98f, 55f)
                rightPath.close()
                
                paint.color = Color.parseColor("#0288D1")
                canvas.drawPath(rightPath, paint)
            }
            "normal" -> {
                // Dibujar 3 capas de la caca clásica
                val layers = arrayOf(
                    floatArrayOf(84f, 82f, 30f, 1f), // Base
                    floatArrayOf(62f, 64f, 26f, 2f), // Media
                    floatArrayOf(42f, 44f, 22f, 3f)  // Superior
                )

                for (layer in layers) {
                    val cy = layer[0]
                    val w = layer[1]
                    val h = layer[2]
                    val type = layer[3]

                    val rect = RectF(64f - w/2f, cy - h/2f, 64f + w/2f, cy + h/2f)
                    
                    val cTop = when (type.toInt()) {
                        1 -> "#8D6E63"
                        2 -> "#795548"
                        else -> "#6D4C41"
                    }
                    val cBottom = when (type.toInt()) {
                        1 -> "#4E342E"
                        2 -> "#3E2723"
                        else -> "#271712"
                    }
                    
                    val layerGrad = LinearGradient(
                        64f, cy - h/2f, 64f, cy + h/2f,
                        Color.parseColor(cTop),
                        Color.parseColor(cBottom),
                        Shader.TileMode.CLAMP
                    )
                    paint.shader = layerGrad
                    canvas.drawRoundRect(rect, h/2f, h/2f, paint)
                    paint.shader = null
                }

                // Punta curvada superior
                val tipPath = Path()
                tipPath.moveTo(64f, 38f)
                tipPath.cubicTo(64f, 38f, 54f, 26f, 66f, 18f)
                tipPath.cubicTo(74f, 12f, 74f, 24f, 64f, 34f)
                tipPath.close()
                
                val tipGrad = LinearGradient(
                    64f, 18f, 64f, 38f,
                    Color.parseColor("#8D6E63"),
                    Color.parseColor("#5D4037"),
                    Shader.TileMode.CLAMP
                )
                paint.shader = tipGrad
                canvas.drawPath(tipPath, paint)
                paint.shader = null
                
                // Brillos premium en el contorno
                paint.color = Color.WHITE
                paint.alpha = 30
                canvas.drawCircle(50f, 55f, 6f, paint)
                canvas.drawCircle(44f, 75f, 8f, paint)
                paint.alpha = 255
            }
            "jurasica" -> {
                // Estructura masiva de caca con grietas de lava naranja
                // Capa Base Gigante
                val baseRect = RectF(16f, 60f, 112f, 108f)
                val baseGrad = LinearGradient(
                    64f, 60f, 64f, 108f,
                    Color.parseColor("#5D4037"),
                    Color.parseColor("#271712"),
                    Shader.TileMode.CLAMP
                )
                paint.shader = baseGrad
                canvas.drawRoundRect(baseRect, 24f, 24f, paint)

                // Capa Media Gigante
                val midRect = RectF(28f, 38f, 100f, 76f)
                val midGrad = LinearGradient(
                    64f, 38f, 64f, 76f,
                    Color.parseColor("#4E342E"),
                    Color.parseColor("#1D0D08"),
                    Shader.TileMode.CLAMP
                )
                paint.shader = midGrad
                canvas.drawRoundRect(midRect, 18f, 18f, paint)

                // Cima Gigante
                val topRect = RectF(42f, 20f, 86f, 48f)
                val topGrad = LinearGradient(
                    64f, 20f, 64f, 48f,
                    Color.parseColor("#3E2723"),
                    Color.parseColor("#150805"),
                    Shader.TileMode.CLAMP
                )
                paint.shader = topGrad
                canvas.drawRoundRect(topRect, 14f, 14f, paint)
                paint.shader = null

                // Grietas brillantes (estilo lava volcánica/jurásica)
                paint.color = Color.parseColor("#FF6D00")
                paint.strokeWidth = 2.5f
                paint.style = Paint.Style.STROKE
                paint.strokeCap = Paint.Cap.ROUND
                
                // Grieta Izquierda
                val crack1 = Path()
                crack1.moveTo(40f, 75f)
                crack1.lineTo(46f, 85f)
                crack1.lineTo(42f, 95f)
                canvas.drawPath(crack1, paint)

                // Grieta Derecha
                val crack2 = Path()
                crack2.moveTo(85f, 50f)
                crack2.lineTo(92f, 62f)
                crack2.lineTo(88f, 74f)
                canvas.drawPath(crack2, paint)

                // Grieta Central
                paint.color = Color.parseColor("#FFD600")
                val crack3 = Path()
                crack3.moveTo(62f, 45f)
                crack3.lineTo(66f, 60f)
                crack3.lineTo(60f, 78f)
                canvas.drawPath(crack3, paint)
                
                paint.style = Paint.Style.FILL
                paint.strokeWidth = 0f
            }
        }

        return bitmap
    }
}
