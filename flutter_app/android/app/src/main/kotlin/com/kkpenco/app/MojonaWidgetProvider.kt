package com.kkpenco.app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent

/**
 * Widget «La Mojona» (1x1): un único botón. El primer toque arma el botón
 * (borde ámbar) y el segundo, dentro de la ventana, registra una KK Normal.
 * El estado armado lo escribe el callback Dart en las prefs de home_widget.
 */
class MojonaWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val ARM_WINDOW_MILLIS = 5500L
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val armedMillis = WidgetData.getLong(context, "mojonaArmedMillis")
        val elapsed = armedMillis?.let { System.currentTimeMillis() - it }
        val isArmed = elapsed != null && elapsed >= 0 && elapsed < ARM_WINDOW_MILLIS

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.mojona_widget_layout)

            views.setImageViewBitmap(R.id.mojona_icon, PoopIconDrawer.draw("normal"))
            views.setTextViewText(R.id.mojona_label, if (isArmed) "¿Seguro?" else "¡YA!")
            views.setInt(
                R.id.mojona_root,
                "setBackgroundResource",
                if (isArmed) R.drawable.poop_widget_background_armed
                else R.drawable.poop_widget_background
            )

            val tapIntent = HomeWidgetBackgroundIntent.getBroadcast(
                context,
                Uri.parse("kkpenco://mojona")
            )
            views.setOnClickPendingIntent(R.id.mojona_root, tapIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
