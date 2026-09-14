package com.example.workers

import android.content.Context
import android.util.Log
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import com.example.data.GroceryGeofenceManager
import com.example.data.HomePlace
import com.example.data.LocationHelper
import com.example.data.SupabaseRepo

/**
 * عينة الليل: مكان الموبايل وهو في البيت (١–٥ الصبح) → [HomePlace.recordNightSample]. لو البيت
 * اتعلّم أو اتنقل، geofences بتتسجل تاني عشان تشمل البيت. مفيش حاجة بتتبعت للسيرفر هنا.
 */
class HomeSampleWorker(appContext: Context, params: WorkerParameters) : CoroutineWorker(appContext, params) {
    override suspend fun doWork(): Result {
        // تذكير الفطار في رمضان بيتجدول من هنا كل ليلة (بيحتاج مكان البيت اللي اتعلّم قبل كده بس).
        com.example.workers.IftarScheduler.scheduleNext(applicationContext)
        if (!GroceryGeofenceManager.isEnabled(applicationContext) ||
            !GroceryGeofenceManager.hasBackgroundLocationPermission(applicationContext)
        ) return Result.success()
        val location = LocationHelper.getCurrentLocation(applicationContext) ?: return Result.success()
        val changed = HomePlace.recordNightSample(applicationContext, location.latitude, location.longitude)
        if (changed) {
            Log.d("HomeSampleWorker", "home learned/moved — re-registering geofences")
            GroceryGeofenceManager.refreshGeofences(applicationContext)
        }
        return Result.success()
    }
}

/** رجع البيت بعد خروجة → zad-brain place_event (وقت الخروج بس، من غير أي إحداثيات). */
class PlaceEventWorker(appContext: Context, params: WorkerParameters) : CoroutineWorker(appContext, params) {
    override suspend fun doWork(): Result {
        val leftAtMs = inputData.getLong(KEY_LEFT_AT, -1L).takeIf { it > 0 } ?: return Result.failure()
        return try {
            val res = SupabaseRepo.callEdgeFunction(
                "zad-brain",
                mapOf("action" to "place_event", "event" to "back_home", "left_at" to java.time.Instant.ofEpochMilli(leftAtMs).toString())
            )
            Log.d("PlaceEventWorker", "place_event → ok=${res["ok"]} status=${res["status"]}")
            Result.success()
        } catch (e: Exception) {
            Log.w("PlaceEventWorker", "place_event failed: ${e.message}")
            if (runAttemptCount < 2) Result.retry() else Result.failure()
        }
    }

    companion object {
        const val KEY_LEFT_AT = "left_at_ms"
        fun enqueue(context: Context, leftAtMs: Long) {
            val request = OneTimeWorkRequestBuilder<PlaceEventWorker>()
                .setInputData(workDataOf(KEY_LEFT_AT to leftAtMs))
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                .build()
            WorkManager.getInstance(context.applicationContext)
                .enqueueUniqueWork("zad_place_back_home_$leftAtMs", ExistingWorkPolicy.KEEP, request)
        }
    }
}
