package com.kkpenco.app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import org.json.JSONArray

/**
 * Widget «El Podio» (3x2): top 3 del grupo y tu posición. El snapshot del
 * ranking lo publica la app (WidgetDataService) al abrirse y al registrar.
 * Tocar el widget abre la app en la pestaña de Clasificación.
 */
class PodioWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val medals = arrayOf("🥇", "🥈", "🥉")
        val rows = intArrayOf(R.id.podio_row_1, R.id.podio_row_2, R.id.podio_row_3)

        // Parsear el snapshot del top-3 (JSON [{name, count}, ...])
        val top = mutableListOf<Pair<String, String>>()
        try {
            val raw = WidgetData.getString(context, "rankTop")
            if (raw != null) {
                val arr = JSONArray(raw)
                for (i in 0 until arr.length()) {
                    val o = arr.getJSONObject(i)
                    top.add(Pair(o.optString("name", "Anónimo"), o.optString("count", "0")))
                }
            }
        } catch (_: Exception) {
            // Datos corruptos o ausentes: se muestra el estado vacío
        }

        val position = WidgetData.getString(context, "rankPosition")
        val totalCount = WidgetData.getString(context, "totalCount")

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.podio_widget_layout)

            if (top.isEmpty()) {
                views.setTextViewText(R.id.podio_row_1, "Abre la app para cargar el ranking")
                views.setViewVisibility(R.id.podio_row_2, View.GONE)
                views.setViewVisibility(R.id.podio_row_3, View.GONE)
                views.setTextViewText(R.id.podio_me, "")
            } else {
                for (i in rows.indices) {
                    if (i < top.size) {
                        views.setViewVisibility(rows[i], View.VISIBLE)
                        views.setTextViewText(rows[i], "${medals[i]} ${top[i].first}   ${top[i].second} 💩")
                    } else {
                        views.setViewVisibility(rows[i], View.GONE)
                    }
                }
                val meLabel = when {
                    position == null -> ""
                    position == "1" -> "Vas primero 👑 ¡que no te pillen!"
                    else -> "Tú: ${position}º (${totalCount ?: "?"}) — ¡a cagar!"
                }
                views.setTextViewText(R.id.podio_me, meLabel)
            }

            val openRanking = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("kkpenco://open?tab=1")
            )
            views.setOnClickPendingIntent(R.id.podio_root, openRanking)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
