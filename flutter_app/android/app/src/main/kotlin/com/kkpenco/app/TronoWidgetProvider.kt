package com.kkpenco.app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent

/**
 * Widget «El Trono» (2x1): abre la app con el cronómetro del tracker ya en
 * marcha. El instante de inicio lo fija la app al recibir el intent (los
 * PendingIntent de RemoteViews son estáticos y no pueden llevar la hora del
 * toque; la diferencia es de ~1 s).
 */
class TronoWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.trono_widget_layout)

            val startTrono = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("kkpenco://open?tab=0&trono=1")
            )
            views.setOnClickPendingIntent(R.id.trono_root, startTrono)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
