package com.example.data

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.util.Log
import androidx.core.content.ContextCompat
import com.example.workers.MomentEventWorker
import java.time.ZonedDateTime

/**
 * "زاد تعرف إنه صحي" (طلب المستخدم ٢٠٢٦-٠٩-١٤): أول فتح لقفل الموبايل الصبح بعد ما الشاشة
 * فضلت مقفولة ٣ ساعات على الأقل = صحي. ساعتها بتقوله صباح الخير بصوتها، ومعاها أدوية
 * ومواعيد النهارده.
 *
 * من غير أي إذن جديد: الاستقبال بيتسجّل جوه [com.example.services.UnifiedBankListener]
 * (خدمة قراءة إشعارات البنك، النظام مخليها شغالة طول الوقت). SCREEN_OFF/USER_PRESENT
 * مابيوصلوش لـreceiver في المانيفست من أندرويد ٨، فلازم يتسجلوا جوه عملية عايشة.
 * العميل اللي الخدمة دي مش متفعلة عنده بياخد تحية احتياطية الساعة ١٠ من السيرفر
 * (ميجريشن 20260914005000) — ونفس dedupe_key فمفيش تحيتين.
 */
object WakeGreeting {
    private const val TAG = "WakeGreeting"
    private const val PREFS = "zad_prefs"
    private const val KEY_SCREEN_OFF_AT = "wake_last_screen_off_ms"
    const val KEY_LAST_GREETING_DATE = "wake_last_greeting_date"
    const val MIN_SLEEP_MS = 3 * 60 * 60 * 1000L
    const val MORNING_START_HOUR = 4
    const val MORNING_END_HOUR = 12 // بدون الساعة ١٢

    /** صافية: هل الفتح ده هو "صحي من النوم"؟ */
    fun shouldGreet(lastScreenOffMs: Long?, lastGreetingDate: String?, now: ZonedDateTime): Boolean {
        if (now.hour < MORNING_START_HOUR || now.hour >= MORNING_END_HOUR) return false
        if (lastGreetingDate == now.toLocalDate().toString()) return false
        if (lastScreenOffMs == null) return false
        return now.toInstant().toEpochMilli() - lastScreenOffMs >= MIN_SLEEP_MS
    }

    fun onScreenOff(context: Context, nowMs: Long = System.currentTimeMillis()) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putLong(KEY_SCREEN_OFF_AT, nowMs).apply()
    }

    fun onUserPresent(context: Context, now: ZonedDateTime = ZonedDateTime.now()) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val lastOff = prefs.getLong(KEY_SCREEN_OFF_AT, -1L).takeIf { it > 0 }
        if (!shouldGreet(lastOff, prefs.getString(KEY_LAST_GREETING_DATE, null), now)) return
        Log.d(TAG, "woke up after ${(now.toInstant().toEpochMilli() - (lastOff ?: 0)) / 60000} min — greeting")
        MomentEventWorker.enqueue(context, "morning_greeting")
    }

    /** بيتسجّل من خدمة إشعارات البنك. بيرجّع الـreceiver عشان الخدمة تشيله وهي بتقفل. */
    fun register(context: Context): BroadcastReceiver {
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context, intent: Intent) {
                when (intent.action) {
                    Intent.ACTION_SCREEN_OFF -> onScreenOff(ctx.applicationContext)
                    Intent.ACTION_USER_PRESENT -> onUserPresent(ctx.applicationContext)
                }
            }
        }
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        ContextCompat.registerReceiver(context, receiver, filter, ContextCompat.RECEIVER_NOT_EXPORTED)
        return receiver
    }
}
