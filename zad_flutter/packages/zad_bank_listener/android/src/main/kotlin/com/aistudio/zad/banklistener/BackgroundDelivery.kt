package com.aistudio.zad.banklistener

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.FlutterCallbackInformation

/**
 * بيوصّل الإشعارات الملتقطة للسيرفر من غير ما العميل يفتح التطبيق.
 *
 * حالتين:
 * - **التطبيق شغال** (محرك الواجهة موجود، حتى لو في الخلفية): بنبعت له `captured`
 *   على القناة، وهو بيفضّي الصندوق ويبعت فوراً بنفس الطابور اللي بيستخدمه دايماً.
 * - **التطبيق مقفول**: بنشغّل محرك Dart من غير واجهة على الدالة اللي التطبيق سجّلها
 *   أول ما اتفتح (`registerBackgroundHandle`) — نفس نمط android_alarm_manager. الدالة
 *   دي بتصنّف وتبعت وتقول `backgroundDone`، والمحرك بيتقفل.
 *
 * التأخير ٤ ثواني مقصود: دفعة واحدة بالفيزا بتطلع ٢-٣ إشعارات ورا بعض (البنك + SMS +
 * المحفظة)، فبتتبعت مع بعض في دورة واحدة بدل ٣ محركات.
 *
 * كل حاجة هنا على الـ main thread — محرك Flutter لازم يتعمل ويتقفل عليه.
 */
internal object BackgroundDelivery {
    private const val TAG = "ZadBankDelivery"
    private const val PREFS = "zad_bank_listener"
    private const val HANDLE_KEY = "background_callback_handle"
    private const val DEBOUNCE_MS = 4_000L
    /** سقف لمحرك الخلفية: لو Dart ماقالش `backgroundDone` (نت واقع، باج) مايفضلش ماسك ذاكرة. */
    private const val WATCHDOG_MS = 90_000L

    private val main = Handler(Looper.getMainLooper())

    /** قناة محرك الواجهة، لو التطبيق شغال. */
    @Volatile
    var uiChannel: MethodChannel? = null

    /** true وإحنا بنبني محرك الخلفية — البلَج-إن بيقراها وهو بيتسجّل عشان مايفتكرش نفسه الواجهة. */
    @Volatile
    var creatingHeadless: Boolean = false
        private set

    private var headless: FlutterEngine? = null
    private var again = false
    private var appContext: Context? = null

    private val deliverRunnable = Runnable { deliverNow() }
    private val watchdog = Runnable {
        Log.w(TAG, "background delivery timed out — stopping the engine; the inbox keeps what was not sent")
        stopHeadless()
    }

    fun saveCallbackHandle(context: Context, handle: Long) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putLong(HANDLE_KEY, handle).apply()
    }

    /** اتلقط حاجة: وصّلها بعد ما الدفعة تخلص. لازم تتنادى على الـ main thread. */
    fun schedule(context: Context) {
        appContext = context.applicationContext
        main.removeCallbacks(deliverRunnable)
        main.postDelayed(deliverRunnable, DEBOUNCE_MS)
    }

    private fun deliverNow() {
        val ui = uiChannel
        if (ui != null) {
            ui.invokeMethod("captured", null)
            return
        }
        if (headless != null) {
            // محرك الخلفية شغال خلاص: يلفّ لفة كمان لما يخلص بدل محرك تاني جنبه.
            again = true
            return
        }
        startHeadless()
    }

    private fun startHeadless() {
        val context = appContext ?: return
        val handle = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getLong(HANDLE_KEY, 0L)
        if (handle == 0L) {
            // التطبيق ماتفتحش ولا مرة بعد التثبيت. الإشعار فاضل في الصندوق لحد أول فتحة.
            Log.w(TAG, "no background handle registered yet — waiting for the app to open")
            return
        }
        val info = FlutterCallbackInformation.lookupCallbackInformation(handle)
        if (info == null) {
            Log.w(TAG, "background handle no longer resolves (app updated?) — waiting for the app to open")
            return
        }
        try {
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(context)
            loader.ensureInitializationComplete(context, null)
            creatingHeadless = true
            val engine = try {
                FlutterEngine(context)
            } finally {
                creatingHeadless = false
            }
            headless = engine
            engine.dartExecutor.executeDartCallback(
                DartExecutor.DartCallback(context.assets, loader.findAppBundlePath(), info),
            )
            main.postDelayed(watchdog, WATCHDOG_MS)
            Log.i(TAG, "background delivery started")
        } catch (e: Exception) {
            Log.e(TAG, "background engine failed to start: ${e.message}")
            stopHeadless()
        }
    }

    /** Dart خلص. */
    fun headlessFinished() {
        main.post { stopHeadless() }
    }

    private fun stopHeadless() {
        main.removeCallbacks(watchdog)
        try {
            headless?.destroy()
        } catch (e: Exception) {
            Log.e(TAG, "engine destroy failed: ${e.message}")
        }
        headless = null
        if (again) {
            again = false
            appContext?.let { schedule(it) }
        }
    }
}
