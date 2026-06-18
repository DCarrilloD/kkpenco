package com.example.kkpenco

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
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

            // Asignar PendingIntents a los botones usando HomeWidgetBackgroundIntent
            val normalIntent = HomeWidgetBackgroundIntent.getBroadcast(
                context,
                Uri.parse("kkpenco://express?consistency=normal")
            )
            views.setOnClickPendingIntent(R.id.btn_normal, normalIntent)

            val jurasicaIntent = HomeWidgetBackgroundIntent.getBroadcast(
                context,
                Uri.parse("kkpenco://express?consistency=jurasica")
            )
            views.setOnClickPendingIntent(R.id.btn_dura, jurasicaIntent)

            val espurruteoIntent = HomeWidgetBackgroundIntent.getBroadcast(
                context,
                Uri.parse("kkpenco://express?consistency=espurruteo")
            )
            views.setOnClickPendingIntent(R.id.btn_liquida, espurruteoIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
