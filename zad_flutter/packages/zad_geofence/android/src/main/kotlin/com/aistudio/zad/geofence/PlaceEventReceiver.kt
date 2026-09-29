package com.aistudio.zad.geofence

import android.annotation.SuppressLint
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import java.util.concurrent.atomic.AtomicBoolean

/**
 * دخول/خروج من نطاق، أو منبّه عينة الليل. بيكتب الحدث في [PlaceEventStore] وبيسيب القرار
 * لـ Dart — مفيش هنا أي منطق عن إيه يستاهل تنبيه.
 */
class PlaceEventReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val app = context.applicationContext
        when (intent.action) {
            Fences.ACTION_FENCE -> onFence(app, intent)
            Fences.ACTION_NIGHT -> onNight(app)
        }
    }

    private fun onFence(context: Context, intent: Intent) {
        val event = GeofencingEvent.fromIntent(intent) ?: return
        if (event.hasError()) {
            Log.e(TAG, "geofence error ${event.errorCode}")
            return
        }
        val transition = when (event.geofenceTransition) {
            Geofence.GEOFENCE_TRANSITION_ENTER -> "enter"
            Geofence.GEOFENCE_TRANSITION_EXIT -> "exit"
            else -> return
        }
        val ids = event.triggeringGeofences?.map { it.requestId }.orEmpty()
        if (ids.isEmpty()) return
        val at = event.triggeringLocation
        PlaceEventStore.get(context).append(ids, transition, System.currentTimeMillis(), at?.latitude, at?.longitude)
        Delivery.schedule(context)
    }

    @SuppressLint("MissingPermission") // hasBackgroundPermission تحت
    private fun onNight(context: Context) {
        Fences.nightFired(context)
        if (!Fences.hasBackgroundPermission(context)) return
        val pending = goAsync()
        val main = Handler(Looper.getMainLooper())
        // goAsync بيدّي ~١٠ ثواني؛ لو الموقع ماجاش قبلها بنسيب الليلة دي.
        val finished = AtomicBoolean(false)
        val giveUp = Runnable { if (finished.compareAndSet(false, true)) pending.finish() }
        main.postDelayed(giveUp, 8_000L)
        LocationServices.getFusedLocationProviderClient(context)
            .getCurrentLocation(Priority.PRIORITY_BALANCED_POWER_ACCURACY, null)
            .addOnCompleteListener { task ->
                if (!finished.compareAndSet(false, true)) return@addOnCompleteListener
                main.removeCallbacks(giveUp)
                val location = if (task.isSuccessful) task.result else null
                if (location != null) {
                    PlaceEventStore.get(context).append(
                        listOf(NIGHT_FENCE), "night", System.currentTimeMillis(),
                        location.latitude, location.longitude,
                    )
                    Delivery.schedule(context)
                }
                pending.finish()
            }
    }

    companion object {
        private const val TAG = "ZadPlaceEvent"
        const val NIGHT_FENCE = "zad_night"
    }
}

/** إعادة التشغيل أو تحديث التطبيق: النطاقات والمنبّه بيرجعوا من غير ما حد يفتح التطبيق. */
class RestoreReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED ->
                Fences.restore(context.applicationContext)
        }
    }
}
