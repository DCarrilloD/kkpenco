package com.kkpenco.app

import android.content.Context
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Lectura de los datos que la app publica para los widgets (los escribe
 * WidgetDataService en Dart). Todos los valores viajan como String para
 * evitar la ambigüedad Integer/Long del canal.
 */
object WidgetData {
    fun getString(context: Context, key: String): String? =
        HomeWidgetPlugin.getData(context).getString(key, null)?.takeIf { it.isNotBlank() }

    fun getLong(context: Context, key: String): Long? =
        getString(context, key)?.toLongOrNull()

    /** Línea de estado de la última KK ("Última: 14:32 ✓", offline, etc.) */
    fun lastPoopLabel(context: Context): String {
        if (getString(context, "lastStatus") == "nosession") {
            return "🔑 Inicia sesión en la app"
        }
        val millis = getLong(context, "lastPoopMillis")
            ?: return "Toca para registrar tu primera KK"
        val time = formatTime(millis)
        return when (getString(context, "lastStatus")) {
            "offline" -> "⏳ $time · pendiente de sincronizar"
            else -> "Última: $time ✓"
        }
    }

    /** HH:mm si es de hoy; dd/MM HH:mm si es anterior */
    fun formatTime(millis: Long): String {
        val now = System.currentTimeMillis()
        val sameDay = SimpleDateFormat("yyyyDDD", Locale.getDefault())
        val pattern = if (sameDay.format(Date(millis)) == sameDay.format(Date(now))) "HH:mm" else "dd/MM HH:mm"
        return SimpleDateFormat(pattern, Locale.getDefault()).format(Date(millis))
    }
}
