package com.example.workers

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.example.data.HomePlace
import com.example.data.RamadanCalendar
import com.example.data.SolarTimes
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.util.concurrent.TimeUnit

/**
 * «فاضل ٢٠ دقيقة على الفطار» بصوت زاد. الموبايل بيحسب المغرب من مكان البيت (مابيطلعش برّه
 * الجهاز)، وبيطلب اللحظة من العقل (moment_event → iftar_soon) — السيرفر بيتأكد إنه رمضان
 * وبيكتب الكلام وبيبعته. من غير مكان بيت متعلّم (تنبيهات الموقع مقفولة) مفيش تذكير.
 */
class IftarReminderWorker(appContext: Context, params: WorkerParameters) : CoroutineWorker(appContext, params) {
    override suspend fun doWork(): Result {
        MomentEventWorker.enqueue(applicationContext, "iftar_soon", """{"minutes_to_iftar":${IftarScheduler.MINUTES_BEFORE}}""")
        IftarScheduler.scheduleNext(applicationContext, Instant.now().plusSeconds(120))
        return Result.success()
    }
}

object IftarScheduler {
    const val MINUTES_BEFORE = 20
    private const val WORK_NAME = "zad_iftar_reminder"

    /** أقرب تذكير فطار بعد [now]: النهارده لو لسه، وإلا بكرة — لو اليوم ده رمضان. null = مفيش. */
    fun nextReminder(now: Instant, zone: ZoneId, lat: Double, lon: Double, isRamadan: (LocalDate) -> Boolean): Instant? {
        val today = now.atZone(zone).toLocalDate()
        for (offset in 0L..1L) {
            val day = today.plusDays(offset)
            if (!isRamadan(day)) continue
            val at = SolarTimes.sunset(day, lat, lon)?.minusSeconds(MINUTES_BEFORE * 60L) ?: continue
            if (at.isAfter(now.plusSeconds(60))) return at
        }
        return null
    }

    fun scheduleNext(context: Context, now: Instant = Instant.now()) {
        val home = HomePlace.homeLocation(context) ?: return
        val zone = ZoneId.systemDefault()
        val at = nextReminder(now, zone, home.first, home.second) { RamadanCalendar.isRamadan(it, zone) } ?: return
        val request = OneTimeWorkRequestBuilder<IftarReminderWorker>()
            .setInitialDelay(Duration.between(Instant.now(), at).toMinutes().coerceAtLeast(1), TimeUnit.MINUTES)
            .build()
        WorkManager.getInstance(context.applicationContext).enqueueUniqueWork(WORK_NAME, ExistingWorkPolicy.REPLACE, request)
        Log.d("IftarScheduler", "next iftar reminder at $at")
    }
}
