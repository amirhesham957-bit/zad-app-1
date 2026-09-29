package com.aistudio.zad.geofence

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
 * بيوصّل أحداث الأماكن لـ Dart — نفس نمط BackgroundDelivery في zad_bank_listener:
 * - **التطبيق مفتوح** (فيه Activity): `events` على قناة الواجهة.
 * - **مقفول**: محرك Dart من غير واجهة على الدالة اللي التطبيق سجّلها، وبيتقفل لما تقول
 *   `backgroundDone` أو بعد [WATCHDOG_MS].
 *
 * قناة الواجهة بتتحدد بالـ Activity مش بترتيب التسجيل: أي محرك خلفية (ده، أو بتاع البنك،
 * أو بتاع FCM) بيسجّل كل البلَج-إنز، ومن غير Activity مايبقاش هو الواجهة.
 */
internal object Delivery {
    private const val TAG = "ZadPlaceDelivery"
    private const val HANDLE_KEY = "background_callback_handle"
    private const val DEBOUNCE_MS = 1_500L
    private const val WATCHDOG_MS = 90_000L

    private val main = Handler(Looper.getMainLooper())

    @Volatile
    var uiChannel: MethodChannel? = null

    private var headless: FlutterEngine? = null
    private var again = false
    private var appContext: Context? = null

    private val deliverRunnable = Runnable { deliverNow() }
    private val watchdog = Runnable {
        Log.w(TAG, "background run timed out — stopping; the events stay in the store")
        stopHeadless()
    }

    fun saveCallbackHandle(context: Context, handle: Long) {
        Fences.prefs(context).edit().putLong(HANDLE_KEY, handle).apply()
    }

    fun schedule(context: Context) {
        appContext = context.applicationContext
        main.removeCallbacks(deliverRunnable)
        main.postDelayed(deliverRunnable, DEBOUNCE_MS)
    }

    private fun deliverNow() {
        val ui = uiChannel
        if (ui != null) {
            ui.invokeMethod("events", null)
            return
        }
        if (headless != null) {
            again = true
            return
        }
        startHeadless()
    }

    private fun startHeadless() {
        val context = appContext ?: return
        val handle = Fences.prefs(context).getLong(HANDLE_KEY, 0L)
        if (handle == 0L) {
            Log.w(TAG, "no background handle yet — waiting for the app to open")
            return
        }
        val info = FlutterCallbackInformation.lookupCallbackInformation(handle)
        if (info == null) {
            Log.w(TAG, "background handle no longer resolves — waiting for the app to open")
            return
        }
        try {
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(context)
            loader.ensureInitializationComplete(context, null)
            val engine = FlutterEngine(context)
            headless = engine
            engine.dartExecutor.executeDartCallback(
                DartExecutor.DartCallback(context.assets, loader.findAppBundlePath(), info),
            )
            main.postDelayed(watchdog, WATCHDOG_MS)
            Log.i(TAG, "background run started")
        } catch (e: Exception) {
            Log.e(TAG, "background engine failed to start: ${e.message}")
            stopHeadless()
        }
    }

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
