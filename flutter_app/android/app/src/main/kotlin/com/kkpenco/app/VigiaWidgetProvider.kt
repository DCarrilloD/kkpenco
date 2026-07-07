package com.kkpenco.app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent

/**
 * Widget «El Vigía» (2x2): racha, contadores de hoy/mes y última KK, con un
 * botón de registro rápido Normal. Tocar el resto abre la app en el tracker.
 * Los datos los publica la app (WidgetDataService) al abrir y al registrar.
 */
class VigiaWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val streak = WidgetData.getString(context, "streak") ?: "0"
        val today = WidgetData.getString(context, "todayCount") ?: "—"
        val month = WidgetData.getString(context, "monthCount") ?: "—"

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.vigia_widget_layout)

            views.setTextViewText(R.id.vigia_streak, "🔥 $streak días")
            views.setTextViewText(R.id.vigia_counters, "Hoy: $today 💩  ·  Mes: $month")
            views.setTextViewText(R.id.vigia_last, WidgetData.lastPoopLabel(context))
            views.setImageViewBitmap(R.id.vigia_btn_icon, PoopIconDrawer.draw("normal"))

            // Botón: registro rápido Normal (mismo flujo/guardias que Express)
            val quickAdd = HomeWidgetBackgroundIntent.getBroadcast(
                context,
                Uri.parse("kkpenco://express?consistency=normal")
            )
            views.setOnClickPendingIntent(R.id.vigia_btn, quickAdd)

            // El resto del widget abre la app en el tracker
            val openApp = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("kkpenco://open?tab=0")
            )
            views.setOnClickPendingIntent(R.id.vigia_root, openApp)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
