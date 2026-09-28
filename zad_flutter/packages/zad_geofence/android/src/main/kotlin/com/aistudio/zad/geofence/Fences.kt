package com.aistudio.zad.geofence

import android.Manifest
import android.annotation.SuppressLint
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import org.json.JSONArray

/**
 * النطاقات المسجّلة عند أندرويد، ومنبّه عينة الليل.
 *
 * القايمة بتتحفظ هنا كمان، لأن أندرويد بيمسح كل النطاقات والمنبّهات مع إعادة التشغيل أو
 * تحديث التطبيق — [RestoreReceiver] بيسجّلها تاني من غير ما يستنى Dart.
 */
internal object Fences {
    private const val TAG = "ZadGeofence"
    const val PREFS = "zad_geofence"
    private const val FENCES_KEY = "fences"
    private const val NIGHT_AT_KEY = "night_at_ms"
    const val STATE_KEY = "state"
    const val ACTION_FENCE = "com.aistudio.zad.geofence.FENCE"
    const val ACTION_NIGHT = "com.aistudio.zad.geofence.NIGHT"
    private const val DAY_MS = 24 * 60 * 60 * 1000L

    fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun hasBackgroundPermission(context: Context): Boolean {
        fun granted(p: String) = context.checkSelfPermission(p) == PackageManager.PERMISSION_GRANTED
        val fine = granted(Manifest.permission.ACCESS_FINE_LOCATION) ||
            granted(Manifest.permission.ACCESS_COARSE_LOCATION)
        val background = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            granted(Manifest.permission.ACCESS_BACKGROUND_LOCATION)
        return fine && background
    }

    private fun fencePendingIntent(context: Context): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            0,
            Intent(context, PlaceEventReceiver::class.java).setAction(ACTION_FENCE),
            // Mutable: Play services writes the transition into this intent.
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
        )

    private fun nightPendingIntent(context: Context): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            1,
            Intent(context, PlaceEventReceiver::class.java).setAction(ACTION_NIGHT),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    /** بيستبدل كل النطاقات بـ [json] (مصفوفة من Dart). [done] بياخد null لو نجح، أو السبب. */
    fun register(context: Context, json: String, done: (String?) -> Unit) {
        prefs(context).edit().putString(FENCES_KEY, json).commit()
        add(context, json, done)
    }

    @SuppressLint("MissingPermission") // hasBackgroundPermission فوق
    private fun add(context: Context, json: String, done: (String?) -> Unit) {
        if (!hasBackgroundPermission(context)) {
            done("no_background_permission")
            return
        }
        val fences = parse(json)
        val client = LocationServices.getGeofencingClient(context)
        val intent = fencePendingIntent(context)
        client.removeGeofences(intent).addOnCompleteListener {
            if (fences.isEmpty()) {
                done(null)
                return@addOnCompleteListener
            }
            val request = GeofencingRequest.Builder()
                // الموبايل جوه نطاق وقت التسجيل = دخول. كده البيت بيعرف إنك فيه من أول لحظة.
                .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
                .addGeofences(fences)
                .build()
            client.addGeofences(request, intent)
                .addOnSuccessListener {
                    Log.i(TAG, "registered ${fences.size} fences")
                    done(null)
                }
                .addOnFailureListener { e ->
                    Log.e(TAG, "addGeofences failed: ${e.message}")
                    done(e.message ?: "add_failed")
                }
        }
    }

    fun clear(context: Context) {
        prefs(context).edit().remove(FENCES_KEY).commit()
        LocationServices.getGeofencingClient(context).removeGeofences(fencePendingIntent(context))
    }

    /** بعد إعادة التشغيل أو التحديث. */
    fun restore(context: Context) {
        val json = prefs(context).getString(FENCES_KEY, null)
        if (json != null) add(context, json) { error -> if (error != null) Log.w(TAG, "restore: $error") }
        val nightAt = prefs(context).getLong(NIGHT_AT_KEY, 0L)
        if (nightAt > 0) scheduleNight(context, nightAt)
    }

    private fun parse(json: String): List<Geofence> {
        val rows = JSONArray(json)
        return (0 until rows.length()).map { i ->
            val row = rows.getJSONObject(i)
            var transitions = 0
            if (row.optBoolean("enter")) transitions = transitions or Geofence.GEOFENCE_TRANSITION_ENTER
            if (row.optBoolean("exit")) transitions = transitions or Geofence.GEOFENCE_TRANSITION_EXIT
            Geofence.Builder()
                .setRequestId(row.getString("id"))
                .setCircularRegion(row.getDouble("lat"), row.getDouble("lon"), row.getDouble("radius").toFloat())
                .setExpirationDuration(Geofence.NEVER_EXPIRE)
                .setTransitionTypes(transitions)
                .build()
        }
    }

    /**
     * عينة الليل الجاية عند [atMs] (Dart بيحسبها بتوقيت سوق الحساب)، وبعدين كل ٢٤ ساعة لوحدها.
     * مش exact: نافذة دقايق مش فارقة لـ «الموبايل فين الساعة ٣ الفجر»، ومش محتاجة صلاحية زيادة.
     */
    fun scheduleNight(context: Context, atMs: Long) {
        var at = atMs
        val now = System.currentTimeMillis()
        while (at <= now) at += DAY_MS
        prefs(context).edit().putLong(NIGHT_AT_KEY, at).commit()
        val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, nightPendingIntent(context))
    }

    fun cancelNight(context: Context) {
        prefs(context).edit().remove(NIGHT_AT_KEY).commit()
        val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarms.cancel(nightPendingIntent(context))
    }

    /** المنبّه رنّ: الليلة الجاية على طول، حتى لو Dart مااشتغلش. */
    fun nightFired(context: Context) {
        val at = prefs(context).getLong(NIGHT_AT_KEY, 0L)
        if (at > 0) scheduleNight(context, at + DAY_MS)
    }
}
