package com.example.data

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.time.ZonedDateTime
import kotlin.math.asin
import kotlin.math.cos
import kotlin.math.pow
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * مكان البيت وخروجات العميل — "روحت فين بقى وصرفت إيه" (طلب المستخدم ٢٠٢٦-٠٩-١٤).
 *
 * الخصوصية في التصميم: **إحداثيات البيت على الموبايل بس**، مابتتبعتش للسيرفر أبدًا. السيرفر
 * بيعرف وقت الخروج والرجوع بس (zad-brain place_event)، وبيحسب الصرف من معاملات عنده أصلاً.
 * وكله شغال بس لو العميل فعّل تنبيهات الموقع ([GroceryGeofenceManager.isEnabled]) — الإفصاح
 * في `location_alerts_toggle_hint`.
 *
 * التعلّم: مكان الموبايل بين ١ و٥ الصبح. ليلتين مختلفتين في نطاق ١٥٠ متر من بعض = البيت.
 * بعدها geofence حوالين البيت (EXIT/ENTER) جوه نفس تسجيل geofences المحلات.
 */
object HomePlace {
    const val GEOFENCE_ID = "zad_home"
    const val RADIUS_METERS = 150f
    const val MIN_AWAY_MS = 45 * 60 * 1000L
    const val MAX_AWAY_MS = 18 * 60 * 60 * 1000L
    private const val PREFS = "zad_home_place"
    private const val KEY_SAMPLES = "night_samples"
    private const val KEY_HOME_LAT = "home_lat"
    private const val KEY_HOME_LON = "home_lon"
    private const val KEY_LEFT_AT = "left_at_ms"
    private const val MAX_SAMPLES = 10

    data class Sample(val lat: Double, val lon: Double, val date: String)

    fun distanceMeters(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        val r = 6_371_000.0
        val dLat = Math.toRadians(lat2 - lat1)
        val dLon = Math.toRadians(lon2 - lon1)
        val a = sin(dLat / 2).pow(2) + cos(Math.toRadians(lat1)) * cos(Math.toRadians(lat2)) * sin(dLon / 2).pow(2)
        return 2 * r * asin(sqrt(a))
    }

    /** صافية: أحدث ليلة + كل الليالي القريبة منها؛ ليلتين مختلفتين على الأقل = البيت (المتوسط). */
    fun learnHome(samples: List<Sample>): Pair<Double, Double>? {
        val latest = samples.lastOrNull() ?: return null
        val cluster = samples.filter { distanceMeters(it.lat, it.lon, latest.lat, latest.lon) <= RADIUS_METERS }
        if (cluster.map { it.date }.distinct().size < 2) return null
        return cluster.map { it.lat }.average() to cluster.map { it.lon }.average()
    }

    fun isNightSampleTime(now: ZonedDateTime): Boolean = now.hour in 1..4

    /** صافية: الغياب ده خروجة تستاهل سؤال؟ */
    fun isOuting(leftAtMs: Long?, nowMs: Long): Boolean =
        leftAtMs != null && nowMs - leftAtMs in MIN_AWAY_MS..MAX_AWAY_MS

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun homeLocation(context: Context): Pair<Double, Double>? {
        val p = prefs(context)
        if (!p.contains(KEY_HOME_LAT)) return null
        return p.getString(KEY_HOME_LAT, null)?.toDoubleOrNull()?.let { lat ->
            p.getString(KEY_HOME_LON, null)?.toDoubleOrNull()?.let { lon -> lat to lon }
        }
    }

    /** بترجع true لو البيت اتعلّم أول مرة أو اتنقل (geofence محتاج يتسجل تاني). */
    fun recordNightSample(context: Context, lat: Double, lon: Double, now: ZonedDateTime = ZonedDateTime.now()): Boolean {
        if (!isNightSampleTime(now)) return false
        val p = prefs(context)
        val arr = try { JSONArray(p.getString(KEY_SAMPLES, "[]")) } catch (_: Exception) { JSONArray() }
        val samples = (0 until arr.length()).mapNotNull { i ->
            arr.optJSONObject(i)?.let { Sample(it.optDouble("lat"), it.optDouble("lon"), it.optString("date")) }
        }.filter { it.date != now.toLocalDate().toString() } + Sample(lat, lon, now.toLocalDate().toString())
        val kept = samples.takeLast(MAX_SAMPLES)
        val out = JSONArray().apply { kept.forEach { put(JSONObject().put("lat", it.lat).put("lon", it.lon).put("date", it.date)) } }
        val learned = learnHome(kept)
        val previous = homeLocation(context)
        val editor = p.edit().putString(KEY_SAMPLES, out.toString())
        val changed = learned != null && (previous == null ||
            distanceMeters(previous.first, previous.second, learned.first, learned.second) > RADIUS_METERS / 2)
        if (learned != null) editor.putString(KEY_HOME_LAT, learned.first.toString()).putString(KEY_HOME_LON, learned.second.toString())
        editor.apply()
        return changed
    }

    fun onLeftHome(context: Context, nowMs: Long = System.currentTimeMillis()) {
        val p = prefs(context)
        if (!p.contains(KEY_LEFT_AT)) p.edit().putLong(KEY_LEFT_AT, nowMs).apply()
    }

    /** بيرجّع وقت الخروج لو الغياب خروجة حقيقية، وبيصفّر الحالة في كل الأحوال. */
    fun onBackHome(context: Context, nowMs: Long = System.currentTimeMillis()): Long? {
        val p = prefs(context)
        val leftAt = p.getLong(KEY_LEFT_AT, -1L).takeIf { it > 0 }
        p.edit().remove(KEY_LEFT_AT).apply()
        return leftAt.takeIf { isOuting(it, nowMs) }
    }
}
