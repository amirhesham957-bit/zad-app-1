package com.aistudio.zad.banklistener

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.util.Log

/**
 * لحظات قفل وفتح الشاشة — مصدر «إيقاع النوم» (ZAD_LIVING_BRAIN.md الشريحة ٣٧، قرار المالك ٢٠٢٦-١٠-٠٣: «أوقات الخمول وقفل
 * الشاشة هي المصدر الأساسي، من غير ما تزعج»).
 *
 * أندرويد مابيبعتش SCREEN_OFF/SCREEN_ON لريسيفر في المانيفست — لازم مكوّن شغال يسجّله. خدمة قراءة الإشعارات شغالة طول ما
 * الصلاحية مفعّلة، فبتسجّله وهي مربوطة. اللحظات بتفضل على الموبايل (آخر [MAX_EVENTS])، وDart بيحسب منها نافذة النوم —
 * **النتيجة بس** بتروح للسيرفر، مش اللحظات.
 */
internal object ScreenEvents {
    private const val PREFS = "zad_screen_events"
    private const val KEY = "events"
    private const val ENABLED = "enabled"
    /** حوالي أسبوعين لموبايل بيتفتح ٥٠ مرة في اليوم. */
    private const val MAX_EVENTS = 800

    private var receiver: BroadcastReceiver? = null

    fun register(context: Context) {
        if (receiver != null) return
        val r = object : BroadcastReceiver() {
            override fun onReceive(c: Context, intent: Intent) {
                when (intent.action) {
                    Intent.ACTION_SCREEN_OFF -> record(c, false)
                    Intent.ACTION_SCREEN_ON -> record(c, true)
                }
            }
        }
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
        }
        try {
            // أندرويد ١٣+ عايز تصريح صريح لأي ريسيفر بيتسجّل وقت التشغيل؛ دي برودكاست النظام، فمش مصدّر.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.registerReceiver(r, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                context.registerReceiver(r, filter)
            }
            receiver = r
        } catch (e: Exception) {
            Log.e(ZadNotificationListenerService.TAG, "screen receiver failed: ${e.message}")
        }
    }

    fun unregister(context: Context) {
        val r = receiver ?: return
        receiver = null
        try {
            context.unregisterReceiver(r)
        } catch (e: Exception) {
            Log.e(ZadNotificationListenerService.TAG, "screen receiver unregister failed: ${e.message}")
        }
    }

    @Synchronized
    fun record(context: Context, on: Boolean) {
        try {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            // العميل قفل التعلّم من «حسابي» ⇒ مفيش تسجيل خالص، مش تسجيل ومسح بعدين.
            if (!prefs.getBoolean(ENABLED, true)) return
            val old = prefs.getString(KEY, "").orEmpty()
            val entry = "${if (on) 1 else 0}:${System.currentTimeMillis()}"
            val all = (if (old.isEmpty()) listOf(entry) else old.split(',') + entry).takeLast(MAX_EVENTS)
            prefs.edit().putString(KEY, all.joinToString(",")).apply()
        } catch (e: Exception) {
            Log.e(ZadNotificationListenerService.TAG, "screen event failed: ${e.message}")
        }
    }

    /** [{on, at}] الأقدم الأول. */
    fun read(context: Context): List<Map<String, Any>> =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, "").orEmpty()
            .split(',').mapNotNull { e ->
                val parts = e.split(':')
                val at = parts.getOrNull(1)?.toLongOrNull() ?: return@mapNotNull null
                mapOf("on" to (parts[0] == "1"), "at" to at)
            }

    /** التعلّم من قفل الشاشة شغال؟ — افتراضي آه (قرار المالك). القفل بيمسح اللحظات اللي اتسجلت. */
    fun setEnabled(context: Context, enabled: Boolean) {
        val edit = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(ENABLED, enabled)
        if (!enabled) edit.remove(KEY)
        edit.apply()
    }
}
