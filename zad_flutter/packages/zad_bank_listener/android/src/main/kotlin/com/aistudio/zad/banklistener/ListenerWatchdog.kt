package com.aistudio.zad.banklistener

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.SystemClock
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.util.Log

/**
 * حارس قراءة البنك وهو التطبيق مقفول (ZAD_PLAN ٢.١).
 *
 * قبل كده الربط من جديد كان بيحصل بس لما العميل يفتح زاد (`BankAccessController.refresh`).
 * المقاس على موبايل المالك (٢١ يوم لحد ٢٠٢٦-١٠-٢٦): `bank.off` ٣ مرات و`bank.stalled` مرة،
 * و`zad_notification_ingest_events` فيها فجوات لحد ٦ أيام. يعني الخدمة بتقع ومحدش بيقول،
 * لحد ما العميل يفتح التطبيق بالصدفة.
 *
 * فالحارس ده بيصحى كل كام ساعة (منبّه مش دقيق، فمش بيصحّي الموبايل في Doze) ومع إعادة
 * التشغيل وتحديث التطبيق: لو الصلاحية موجودة بيطلب ربط الخدمة تاني، ولو الخدمة باينة ميتة
 * أو الصلاحية اتشالت بعد ما كانت شغالة، بيطلّع إشعار واحد في اليوم بالكتير «اضغط للإصلاح».
 *
 * اللي مايقدرش يعمله: لو النظام عمل «إيقاف إجباري» للتطبيق (شاومي بتعمله)، المنبّهات نفسها
 * بتتمسح لحد أول فتحة. ده اللي إعفاء البطارية بيقفله، مش الكود ده.
 */
internal object ListenerWatchdog {

    enum class Verdict { FINE, REVOKED, STALLED }

    /**
     * نفس [kListenerStallAfter] في Dart: الخدمة بتشوف كل إشعارات الموبايل، فـ١٢ ساعة صمت = ميتة. كانت يومين؛ شاومي
     * المالك كانت بتوقفها كل يوم ودفعة BDC يوم ٦/١١ ماوصلتش، فالتنبيه كان بيجي بعد يومين مصاريف (٧/١١).
     */
    const val STALL_AFTER_MS = 12L * 60 * 60 * 1000

    /** تنبيه واحد في اليوم بالكتير، مهما الحارس صحي. */
    const val ALERT_EVERY_MS = 24L * 60 * 60 * 1000

    const val CHECK_EVERY_MS = 3L * 60 * 60 * 1000

    private const val LAST_ALERT_AT = "watchdog_last_alert_at"
    private const val CHANNEL_ID = "zad_bank_watchdog"
    private const val NOTIFICATION_ID = 99002
    const val ACTION_CHECK = "com.aistudio.zad.banklistener.WATCHDOG_CHECK"

    /**
     * حالة القناة من اللي الخدمة سجّلته. اللي عمره ما فعّل القراية مابيتنبّهش —
     * ده قرار العميل مش عطل.
     */
    fun verdict(granted: Boolean, lastConnectedAt: Long?, lastSeenAnyAt: Long?, now: Long): Verdict {
        if (lastConnectedAt == null) return Verdict.FINE
        if (!granted) return Verdict.REVOKED
        val seen = maxOf(lastSeenAnyAt ?: 0L, lastConnectedAt)
        return if (now - seen >= STALL_AFTER_MS) Verdict.STALLED else Verdict.FINE
    }

    fun shouldAlert(verdict: Verdict, lastAlertAt: Long?, now: Long): Boolean =
        verdict != Verdict.FINE && (lastAlertAt == null || now - lastAlertAt >= ALERT_EVERY_MS)

    /**
     * بتتقرا من `enabled_notification_listeners` مباشرة. `isNotificationListenerAccessGranted`
     * موجودة من API 27 بس، والتطبيق minSdk بتاعه 24.
     */
    fun isGranted(context: Context): Boolean {
        val flat = Settings.Secure.getString(
            context.contentResolver,
            "enabled_notification_listeners",
        ) ?: return false
        val me = ComponentName(context, ZadNotificationListenerService::class.java)
        return flat.split(':').any {
            val parsed = ComponentName.unflattenFromString(it)
            parsed != null && parsed == me
        }
    }

    /**
     * بيطلب من النظام يربط الخدمة تاني. no-op لو مربوطة أصلاً. الربط مابيحصلش لو الصلاحية
     * مش ممنوحة، فبترجع false ساعتها بدل ما تدّعي نجاح.
     */
    fun rebind(context: Context): Boolean {
        if (!isGranted(context)) return false
        NotificationListenerService.requestRebind(
            ComponentName(context, ZadNotificationListenerService::class.java),
        )
        return true
    }

    /**
     * الخدمة صامتة من [STALL_AFTER_MS] والصلاحية موجودة: [rebind] لوحده بيتجاهله شاومي (المالك ١٠/١١: «وقف — اضغط
     * للإصلاح» والضغط مابيعملش حاجة، و`bank.stalled` ٥ مرات في اليوم). قفل المكوّن وفتحه بيخلي النظام يشيل الخدمة
     * ويسجّلها من جديد فيربطها. بس لما تكون صامتة: خدمة شغالة ماتتلمسش.
     */
    fun repair(context: Context): Boolean {
        if (!isGranted(context)) return false
        val now = System.currentTimeMillis()
        val stalled = verdict(
            true,
            ZadNotificationListenerService.readMillis(context, ZadNotificationListenerService.LAST_CONNECTED_AT),
            ZadNotificationListenerService.readMillis(context, ZadNotificationListenerService.LAST_SEEN_ANY_AT),
            now,
        ) == Verdict.STALLED
        if (stalled) toggleComponent(context)
        return rebind(context)
    }

    /** المكوّن بيتقفل ويرجع لحالته في المانيفست (شغّال)، من غير ما التطبيق يتقتل. */
    private fun toggleComponent(context: Context) {
        val component = ComponentName(context, ZadNotificationListenerService::class.java)
        val pm = context.packageManager
        try {
            pm.setComponentEnabledSetting(
                component, PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP,
            )
            pm.setComponentEnabledSetting(
                component, PackageManager.COMPONENT_ENABLED_STATE_DEFAULT, PackageManager.DONT_KILL_APP,
            )
        } catch (e: Exception) {
            Log.e("ZadBankWatchdog", "component toggle failed: ${e.message}")
        }
    }

    /** منبّه متكرر مش دقيق. نفس الـPendingIntent بيستبدل اللي قبله، فالنداء المتكرر آمن. */
    fun schedule(context: Context) {
        val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarms.setInexactRepeating(
            AlarmManager.ELAPSED_REALTIME,
            SystemClock.elapsedRealtime() + CHECK_EVERY_MS,
            CHECK_EVERY_MS,
            checkIntent(context),
        )
    }

    fun check(context: Context) {
        val granted = isGranted(context)
        if (granted) repair(context)
        val now = System.currentTimeMillis()
        val v = verdict(
            granted,
            ZadNotificationListenerService.readMillis(context, ZadNotificationListenerService.LAST_CONNECTED_AT),
            ZadNotificationListenerService.readMillis(context, ZadNotificationListenerService.LAST_SEEN_ANY_AT),
            now,
        )
        val lastAlert = ZadNotificationListenerService.readMillis(context, LAST_ALERT_AT)
        if (!shouldAlert(v, lastAlert, now)) return
        if (alert(context, v)) ZadNotificationListenerService.markNow(context, LAST_ALERT_AT)
    }

    private fun checkIntent(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context,
        0,
        Intent(context, WatchdogReceiver::class.java).setAction(ACTION_CHECK),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    /** true لو الإشعار اتنشر فعلاً. */
    @Suppress("DEPRECATION")
    private fun alert(context: Context, verdict: Verdict): Boolean {
        if (Build.VERSION.SDK_INT >= 33 &&
            context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return false
        }
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        // الصلاحية اتشالت: الحل الوحيد شاشة النظام. الخدمة واقفة: فتح زاد بيطلب الربط ويوري «اضغط للإصلاح».
        val target = if (verdict == Verdict.REVOKED) {
            Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
        } else {
            context.packageManager.getLaunchIntentForPackage(context.packageName) ?: return false
        }.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        val tap = PendingIntent.getActivity(
            context,
            NOTIFICATION_ID,
            target,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val (title, body) = if (verdict == Verdict.REVOKED) {
            "زاد بطّل يقرا رسايل البنك" to
                "صلاحية قراءة الإشعارات اتقفلت. اضغط وشغّلها لزاد تاني عشان مشترياتك تتسجل لوحدها."
        } else {
            "قراءة البنك واقفة من يومين" to
                "الموبايل قفل خدمة زاد في الخلفية. اضغط عشان ترجع تشتغل."
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "قراءة البنك", NotificationManager.IMPORTANCE_DEFAULT),
            )
            Notification.Builder(context, CHANNEL_ID)
        } else {
            Notification.Builder(context)
        }
        builder
            .setSmallIcon(android.R.drawable.stat_sys_warning)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setContentIntent(tap)
            .setAutoCancel(true)
        manager.notify(NOTIFICATION_ID, builder.build())
        return true
    }
}

/** المنبّه، وإعادة التشغيل، وتحديث التطبيق — التلاتة بيمسحوا أو بيفكّوا الخدمة. */
class WatchdogReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        try {
            when (intent?.action) {
                Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED -> {
                    ListenerWatchdog.schedule(context)
                    ListenerWatchdog.rebind(context)
                }
                ListenerWatchdog.ACTION_CHECK -> ListenerWatchdog.check(context)
            }
        } catch (e: Exception) {
            Log.e(ZadNotificationListenerService.TAG, "watchdog failed: ${e.message}")
        }
    }
}
