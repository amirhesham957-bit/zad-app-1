package com.aistudio.zad.geofence

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * صندوق الأحداث: كل دخول/خروج من نطاق، وكل عينة ليل، بتتكتب هنا قبل أي حاجة تانية —
 * محرك Dart ممكن يكون مش موجود، أو النت واقع. Dart بيقرا (peek) وبعدين بيأكّد (acknowledge)،
 * فلو مات في النص الحدث بيفضل.
 *
 * SharedPreferences مش SQLite: الأحداث قليلة (كام واحد في اليوم) وليها سقف.
 */
internal class PlaceEventStore private constructor(context: Context) {
    private val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    @Synchronized
    fun append(fences: List<String>, transition: String, atMs: Long, lat: Double?, lon: Double?) {
        val rows = read()
        var next = prefs.getLong(NEXT_KEY, 1L)
        for (fence in fences) {
            val row = JSONObject()
                .put("key", next++)
                .put("fence", fence)
                .put("transition", transition)
                .put("at", atMs)
            if (lat != null && lon != null) row.put("lat", lat).put("lon", lon)
            rows.put(row)
        }
        // الأقدم بيتشال لو الصندوق اتملى — حدث عمره أيام مالوش لازمة.
        val kept = JSONArray()
        val from = maxOf(0, rows.length() - MAX_ROWS)
        for (i in from until rows.length()) kept.put(rows.get(i))
        prefs.edit().putString(ROWS_KEY, kept.toString()).putLong(NEXT_KEY, next).commit()
    }

    @Synchronized
    fun peek(): List<Map<String, Any?>> {
        val rows = read()
        return (0 until rows.length()).map { i ->
            val row = rows.getJSONObject(i)
            mapOf(
                "key" to row.getLong("key"),
                "fence" to row.getString("fence"),
                "transition" to row.getString("transition"),
                "at" to row.getLong("at"),
                "lat" to if (row.has("lat")) row.getDouble("lat") else null,
                "lon" to if (row.has("lon")) row.getDouble("lon") else null,
            )
        }
    }

    @Synchronized
    fun acknowledge(keys: Set<Long>) {
        val rows = read()
        val kept = JSONArray()
        for (i in 0 until rows.length()) {
            val row = rows.getJSONObject(i)
            if (row.getLong("key") !in keys) kept.put(row)
        }
        prefs.edit().putString(ROWS_KEY, kept.toString()).commit()
    }

    private fun read(): JSONArray = try {
        JSONArray(prefs.getString(ROWS_KEY, "[]"))
    } catch (_: Exception) {
        JSONArray()
    }

    companion object {
        private const val PREFS = "zad_geofence_events"
        private const val ROWS_KEY = "rows"
        private const val NEXT_KEY = "next_key"
        private const val MAX_ROWS = 100

        @Volatile
        private var instance: PlaceEventStore? = null

        fun get(context: Context): PlaceEventStore =
            instance ?: synchronized(this) {
                instance ?: PlaceEventStore(context.applicationContext).also { instance = it }
            }
    }
}
