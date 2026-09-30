package com.aistudio.zad.banklistener

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.service.notification.NotificationListenerService
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** يوصّل صندوق الإشعارات الملتقطة وحالة الصلاحية لـ Dart. */
class ZadBankListenerPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {

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
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        if (BackgroundDelivery.uiChannel === channel) BackgroundDelivery.uiChannel = null
    }

    // الواجهة = المحرك اللي عنده Activity، زي zad_geofence. كان أي محرك Dart غير محرك البنك
    // نفسه بيتحسب واجهة — بما فيهم محرك FCM ومحرك الـgeofence في الخلفية — فإشعار «اتلقط»
    // كان ممكن يروح لمحرك مالوش مستمع ويستنى لحد أول فتحة (ZAD_SUPER_AGENT.md نقطة ١٠).
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        BackgroundDelivery.uiChannel = channel
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        BackgroundDelivery.uiChannel = channel
    }

    override fun onDetachedFromActivityForConfigChanges() {}

    override fun onDetachedFromActivity() {
        if (BackgroundDelivery.uiChannel === channel) BackgroundDelivery.uiChannel = null
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
                // كوتلن BankReadingStatus.sendTestNotification: إشعار حقيقي بيمشي على نفس
                // مسار المستمع، بعلامة person مستقلة عن اللغة.
                "sendTestNotification" -> {
                    sendTestNotification(
                        call.argument<String>("title") ?: "",
                        call.argument<String>("body") ?: "",
                    )
                    result.success(null)
                }
                // كوتلن BankReadingStatus: آخر ربط للخدمة وآخر إشعار شافته (أي إشعار).
                "listenerStatus" -> result.success(
                    mapOf(
                        "lastConnectedAt" to ZadNotificationListenerService.readMillis(
                            context, ZadNotificationListenerService.LAST_CONNECTED_AT,
                        ),
                        "lastSeenAnyAt" to ZadNotificationListenerService.readMillis(
                            context, ZadNotificationListenerService.LAST_SEEN_ANY_AT,
                        ),
                        "testSentAt" to ZadNotificationListenerService.readMillis(
                            context, ZadNotificationListenerService.TEST_AT,
                        ),
                        "testResult" to context.getSharedPreferences(
                            ZadNotificationListenerService.PREFS, Context.MODE_PRIVATE,
                        ).getString(ZadNotificationListenerService.TEST_RESULT, null),
                    ),
                )
                // الدالة اللي محرك الخلفية بيشغّلها لما إشعار يوصل والتطبيق مقفول.
                "registerBackgroundHandle" -> {
                    val handle = call.argument<Number>("handle")?.toLong() ?: 0L
                    if (handle != 0L) BackgroundDelivery.saveCallbackHandle(context, handle)
                    result.success(null)
                }
                // أندرويد ١٣+ بيقفل «قراءة الإشعارات» تحت «إعدادات مقيدة» لأي تطبيق
                // متثبت من ملف (مش من متجر). الواجهة محتاجة تعرف ده عشان تشرح الخطوة.
                "installInfo" -> result.success(
                    mapOf("sdk" to Build.VERSION.SDK_INT, "installer" to installerPackage()),
                )
                // «معلومات التطبيق» — منها ⋮ ← «السماح بالإعدادات المقيدة»، ومنها البطارية.
                "openAppDetails" -> {
                    val intent = Intent(
                        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.fromParts("package", context.packageName, null),
                    ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(intent)
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

    /** مين ثبّت التطبيق: `com.android.vending` = جوجل بلاي، null = ملف APK في الغالب. */
    private fun installerPackage(): String? = try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            context.packageManager.getInstallSourceInfo(context.packageName).installingPackageName
        } else {
            @Suppress("DEPRECATION")
            context.packageManager.getInstallerPackageName(context.packageName)
        }
    } catch (e: Exception) {
        null
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

    @Suppress("DEPRECATION")
    private fun sendTestNotification(title: String, body: String) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE)
            as android.app.NotificationManager
        val channelId = "zad_test_channel"
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                android.app.NotificationChannel(
                    channelId, "Zad test", android.app.NotificationManager.IMPORTANCE_DEFAULT,
                ),
            )
            android.app.Notification.Builder(context, channelId)
        } else {
            android.app.Notification.Builder(context)
        }
        builder
            .setSmallIcon(android.R.drawable.ic_menu_manage)
            .setContentTitle(title)
            .setContentText(body)
            .addPerson(ZadNotificationListenerService.TEST_MARKER_PERSON)
        val canPost = Build.VERSION.SDK_INT < 33 ||
            context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) ==
            android.content.pm.PackageManager.PERMISSION_GRANTED
        if (canPost) manager.notify(99001, builder.build())
        context.getSharedPreferences(ZadNotificationListenerService.PREFS, Context.MODE_PRIVATE)
            .edit()
            .putLong(ZadNotificationListenerService.TEST_AT, System.currentTimeMillis())
            .putString(ZadNotificationListenerService.TEST_RESULT, "sent")
            .apply()
    }
}
