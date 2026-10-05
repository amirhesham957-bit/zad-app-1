package com.aistudio.zad.banklistener

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

/**
 * بيسمع إشعارات النظام وبيحفظ اللي ممكن يكون رسالة بنك، وبعدين بيوصّلها فوراً.
 *
 * **الخدمة دي مابتقرّرش إذا كانت معاملة.** الفلترة الحقيقية — الضجيج، المبلغ، التصنيف،
 * البوابة — في Dart (`bank_notification.dart`) ومقفولة باختبارات تطابق مع
 * `SaBankParser.kt`. اللي هنا بيستبعد بس: التطبيق نفسه، والتطبيقات اللي مالهاش علاقة
 * بالفلوس أبداً (النظام، المتاجر، الشات — [NotificationContent.IGNORED_PACKAGES])،
 * والإشعارات اللي مفيهاش نص.
 *
 * رسايل البنك **بتوصل من حزمة مش متتبَّعة**: `com.google.android.apps.messaging`
 * — تطبيق المراسلة نفسه. فأي تضييق على "الحزم المعروفة" كان هيقفل القناة الأساسية.
 * (CLAUDE.md — قسم إشعارات البنوك.)
 *
 * **التوصيل (٢٠٢٦-٠٩-٢٥):** قبل كده الصندوق كان بيتفضّى بس لما العميل يفتح التطبيق —
 * يعني تدفع بالفيزا ومايوصلكش سؤال التأكيد غير لما تفتح زاد. من ٢٠٢٦-٠٩-١٥ لحد
 * ٢٠٢٦-٠٩-٢٥ ولا إشعار واحد وصل السيرفر. كوتلن كان بيبعت من جوه الخدمة نفسها؛ هنا
 * [BackgroundDelivery] بيعمل نفس الحاجة: بينبّه التطبيق لو شغال، أو بيشغّل Dart من
 * غير واجهة لو مقفول.
 */
class ZadNotificationListenerService : NotificationListenerService() {

    private val store by lazy { CapturedNotificationStore.get(applicationContext) }
    private val main by lazy { Handler(Looper.getMainLooper()) }

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.i(TAG, "listener connected; pending=${store.pending()}")
        // كوتلن BankReadingStatus.recordListenerConnected: الصلاحية مش معناها الخدمة مربوطة.
        markNow(applicationContext, LAST_CONNECTED_AT)
        // إيقاع النوم (الشريحة ٣٧): لحظات قفل/فتح الشاشة طول ما الخدمة مربوطة.
        ScreenEvents.register(applicationContext)
        // أول ما الصلاحية تتفعّل (أو أندرويد يربط الخدمة من جديد) الإشعارات اللي لسه
        // ظاهرة في الشريط ماعدّتش على onNotificationPosted. كوتلن كان بيلمّها هنا؛ المفاتيح
        // اللي اتشافت قبل كده بتتحفظ عشان إعادة الربط ماتبعتش نفس الرسالة تاني.
        try {
            val prefs = applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val seen = prefs.getStringSet(SEEN_KEYS, emptySet()).orEmpty().toMutableSet()
            var added = 0
            activeNotifications?.forEach { sbn ->
                if (sbn.key in seen) return@forEach
                seen += sbn.key
                if (capture(sbn)) added++
            }
            val trimmed = if (seen.size > MAX_SEEN_KEYS) seen.toList().takeLast(MAX_SEEN_KEYS).toSet() else seen
            prefs.edit().putStringSet(SEEN_KEYS, trimmed).apply()
            if (added > 0) main.post { BackgroundDelivery.schedule(applicationContext) }
        } catch (e: Exception) {
            Log.e(TAG, "active notification scan failed: ${e.message}")
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        val notification = sbn ?: return
        // كوتلن BankReadingStatus.recordSawNotification: **أي** إشعار، حتى لو اتفلتر بعد كده —
        // من غيره مفيش فرق بين "الخدمة ميتة" و"الخدمة شغالة والفلترة رمت كل حاجة".
        try {
            markNow(applicationContext, LAST_SEEN_ANY_AT)
            // كوتلن UnifiedBankListener: الإشعار التجريبي بيتعرف من الـperson مش النص،
            // فالكشف شغال مهما كانت لغة التطبيق.
            val people = notification.notification?.extras
                ?.getStringArray(android.app.Notification.EXTRA_PEOPLE)
            if (people?.contains(TEST_MARKER_PERSON) == true) {
                applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                    .edit().putString(TEST_RESULT, "received_by_listener").apply()
            }
        } catch (e: Exception) {
            Log.e(TAG, "mark seen failed: ${e.message}")
        }
        try {
            if (capture(notification)) {
                // Handler مش استدعاء مباشر: محرك Flutter لازم يتعمل على الـ main thread،
                // وأندرويد مابيضمنش إن onNotificationPosted عليه.
                main.post { BackgroundDelivery.schedule(applicationContext) }
            }
        } catch (e: Exception) {
            // الخدمة دي بتشتغل على كل إشعار على الجهاز. استثناء واحد بيوقّعها،
            // وأندرويد ساعات مابيرجعش يربطها — فالقناة البنكية كلها تقف بسبب
            // إشعار واحد غريب الشكل.
            Log.e(TAG, "capture failed: ${e.message}")
        }
    }

    /** بيحفظ الإشعار لو يستاهل. true لو اتحفظ. */
    private fun capture(sbn: StatusBarNotification): Boolean {
        if (NotificationContent.isIgnored(sbn.packageName, applicationContext.packageName)) return false
        val extras = sbn.notification?.extras ?: return false
        val (title, text) = NotificationContent.extract(extras)
        // مفيش نص = مفيش رسالة (تقدّم تحميل، تشغيل صوت).
        if (title.isBlank() && text.isBlank()) return false
        store.insert(
            packageName = sbn.packageName,
            title = title,
            text = text,
            postedAt = sbn.postTime,
        )
        return true
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) = Unit

    override fun onListenerDisconnected() {
        ScreenEvents.unregister(applicationContext)
        super.onListenerDisconnected()
    }

    override fun onDestroy() {
        ScreenEvents.unregister(applicationContext)
        super.onDestroy()
    }

    internal companion object {
        const val TAG = "ZadBankListener"
        const val PREFS = "zad_bank_listener"
        const val LAST_CONNECTED_AT = "last_connected_at"
        const val LAST_SEEN_ANY_AT = "last_seen_any_at"
        const val TEST_MARKER_PERSON = "test:zad-diagnostic"
        const val TEST_AT = "test_sent_at"
        const val TEST_RESULT = "test_result"

        fun markNow(context: Context, key: String) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit().putLong(key, System.currentTimeMillis()).apply()
        }

        fun readMillis(context: Context, key: String): Long? {
            val v = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getLong(key, -1L)
            return if (v > 0) v else null
        }
        private const val SEEN_KEYS = "seen_active_keys"
        private const val MAX_SEEN_KEYS = 300
    }
}
