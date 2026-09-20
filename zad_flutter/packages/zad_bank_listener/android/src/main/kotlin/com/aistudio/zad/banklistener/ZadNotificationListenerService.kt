package com.aistudio.zad.banklistener

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

/**
 * بيسمع إشعارات النظام وبيحفظ اللي ممكن يكون رسالة بنك.
 *
 * **الخدمة دي مابتقرّرش.** كل الفلترة الحقيقية — الضجيج، المبلغ، التصنيف،
 * البوابة — في Dart (`bank_notification.dart`) ومقفولة باختبارات تطابق مع
 * `SaBankParser.kt`. اللي هنا بيستبعد حاجتين بس: إشعارات التطبيق نفسه،
 * والإشعارات اللي مفيهاش نص أصلاً.
 *
 * السبب إن الفلترة مش هنا مقيس مش مفترض. الرسايل البنكية في المشروع ده
 * **بتوصل من حزمة مش متتبَّعة**: `com.google.android.apps.messaging` — تطبيق
 * المراسلة نفسه — مش في قايمة الـ١٧٠ حزمة مالية ولا هيبقى. مسح كل
 * `zad_notification_ingest_events` لقى إن **كل** المعاملات المسجّلة وصلت من
 * المسار ده. فأي تضييق هنا على "الحزم المعروفة" كان هيقفل القناة الأساسية،
 * مش يفلتر الضجيج. (CLAUDE.md — قسم إشعارات البنوك.)
 *
 * والتقاط عريض مش مكلّف: الصندوق سقفه ٥٠٠ صف، والقرار الغالي بيحصل مرة واحدة
 * في Dart لما التطبيق يفتح.
 */
class ZadNotificationListenerService : NotificationListenerService() {

    private val store by lazy { CapturedNotificationStore(applicationContext) }

    override fun onListenerConnected() {
        super.onListenerConnected()
        // صلاحية ممنوحة مش معناها خدمة مربوطة — أندرويد بيقتل الـ listener تحت
        // ضغط الذاكرة أو بعد تحديث وساعات مابيرجعش يربطه لوحده. السطر ده بيخلي
        // الحالة دي مرئية في اللوج بدل ما تفضل "الجدول فاضي وماحدش يعرف ليه".
        Log.i(TAG, "listener connected; pending=${store.pending()}")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        val notification = sbn ?: return
        try {
            if (notification.packageName == applicationContext.packageName) return

            val extras = notification.notification?.extras ?: return
            val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
            val text = (
                extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
                    ?: extras.getCharSequence(Notification.EXTRA_TEXT)
                )?.toString().orEmpty()

            // مفيش نص = مفيش رسالة. الإشعارات دي (تقدّم تحميل، تشغيل صوت) مالهاش
            // أي طريق تبقى معاملة.
            if (title.isBlank() && text.isBlank()) return

            store.insert(
                packageName = notification.packageName,
                title = title,
                text = text,
                postedAt = notification.postTime,
            )
        } catch (e: Exception) {
            // الخدمة دي بتشتغل على كل إشعار على الجهاز. استثناء واحد بيوقّعها،
            // وأندرويد ساعات مابيرجعش يربطها — فالقناة البنكية كلها تقف بسبب
            // إشعار واحد غريب الشكل.
            Log.e(TAG, "capture failed: ${e.message}")
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) = Unit

    internal companion object {
        const val TAG = "ZadBankListener"
    }
}
