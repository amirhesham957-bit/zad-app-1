package com.aistudio.zad.banklistener

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.service.notification.NotificationListenerService
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** يوصّل صندوق الإشعارات الملتقطة وحالة الصلاحية لـ Dart. */
class ZadBankListenerPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private val store by lazy { CapturedNotificationStore.get(context) }

    /** البلَج-إن ده متسجّل في محرك الخلفية (BackgroundDelivery)، مش في التطبيق نفسه. */
    private var inBackgroundEngine = false

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
        inBackgroundEngine = BackgroundDelivery.creatingHeadless
        if (!inBackgroundEngine) BackgroundDelivery.uiChannel = channel
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        if (!inBackgroundEngine && BackgroundDelivery.uiChannel === channel) {
            BackgroundDelivery.uiChannel = null
        }
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
        try {
            when (call.method) {
                "isPermissionGranted" -> result.success(isPermissionGranted())
                "openPermissionSettings" -> {
                    openPermissionSettings()
                    result.success(null)
                }
                // ربط من جديد بعد ما أندرويد فكّ الخدمة. no-op لو مربوطة أصلاً،
                // وهو المقصود: بيتنادى كل فتحة للتطبيق.
                "requestRebind" -> {
                    result.success(requestRebind())
                }
                "peek" -> result.success(store.peek(call.argument<Int>("limit") ?: 100))
                "acknowledge" -> {
                    val ids = call.argument<List<Number>>("ids").orEmpty().map { it.toLong() }
                    store.deleteUpTo(ids)
                    result.success(null)
                }
                "pendingCount" -> result.success(store.pending())
                // الدالة اللي محرك الخلفية بيشغّلها لما إشعار يوصل والتطبيق مقفول.
                "registerBackgroundHandle" -> {
                    val handle = call.argument<Number>("handle")?.toLong() ?: 0L
                    if (handle != 0L) BackgroundDelivery.saveCallbackHandle(context, handle)
                    result.success(null)
                }
                "backgroundDone" -> {
                    if (inBackgroundEngine) BackgroundDelivery.headlessFinished()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("zad_bank_listener", e.message, null)
        }
    }

    /**
     * الصلاحية ممنوحة؟
     *
     * بتتقرا من `enabled_notification_listeners` مباشرة. `isNotificationListenerAccessGranted`
     * موجودة من API 27 بس، والتطبيق minSdk بتاعه 24.
     */
    private fun isPermissionGranted(): Boolean {
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

    private fun openPermissionSettings() {
        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }

    /**
     * بيطلب من النظام يربط الخدمة تاني.
     *
     * `requestRebind` من API 24، لكن الربط نفسه مابيحصلش لو الصلاحية مش ممنوحة —
     * فالفحص الأول مش زيادة. بترجع false لما مفيش حاجة تتعمل، عشان الواجهة
     * تقدر تفرّق بين "طلبنا" و"مش ممنوح أصلاً" بدل ما تدّعي نجاح.
     */
    private fun requestRebind(): Boolean {
        if (!isPermissionGranted()) return false
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return false
        NotificationListenerService.requestRebind(
            ComponentName(context, ZadNotificationListenerService::class.java),
        )
        return true
    }

    private companion object {
        const val CHANNEL = "com.aistudio.zad/bank_listener"
    }
}
