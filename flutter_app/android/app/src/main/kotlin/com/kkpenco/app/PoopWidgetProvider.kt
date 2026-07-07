package com.kkpenco.app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent

/**
 * Widget «Express» (4x1): botonera de consistencias para el registro rápido.
 * OJO: el nombre de clase no puede cambiar — renombrarlo eliminaría los
 * widgets ya colocados en los escritorios del grupo.
 */
class PoopWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.poop_widget_layout)

            // Generar y asignar las imágenes dibujadas con Canvas nativo
            views.setImageViewBitmap(R.id.img_cabra, PoopIconDrawer.draw("cabra"))
            views.setImageViewBitmap(R.id.img_espurruteo, PoopIconDrawer.draw("espurruteo"))
            views.setImageViewBitmap(R.id.img_normal, PoopIconDrawer.draw("normal"))
            views.setImageViewBitmap(R.id.img_jurasica, PoopIconDrawer.draw("jurasica"))

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

            // Línea de estado: última KK / pendiente de sincronizar / sin sesión
            views.setTextViewText(R.id.widget_status, WidgetData.lastPoopLabel(context))

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
