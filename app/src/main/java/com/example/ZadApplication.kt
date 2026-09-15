package com.example

import android.app.ActivityManager
import android.app.Application
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import com.example.ads.RewardedBrainAdManager

/**
 * موجودة عشان حاجة واحدة: تلف الـ base context بتاع التطبيق كله باللغة اللي العميل
 * اختارها.
 *
 * `MainActivity.attachBaseContext` كانت بتعمل ده للشاشات — وبس. أي كود بيقرا نصوص
 * وهو برّه الـ Activity (الـ Workers، الـ BroadcastReceivers، الـ Services) بيستخدم
 * `applicationContext`، وده كان بيتحلّ من **لغة النظام** مش من اختيار العميل. النتيجة
 * اللي العميل شافها: التطبيق بالعربي، والإشعارات بتوصل بالإنجليزي — تليفون لغته
 * إنجليزي، وتسعة أماكن بتبني إشعارات (تذكير الجرعات، ملخص الصباح، تنبيهات الميزانية،
 * التسبيح، الجيوفنس، الشات، المواسم) كلهم بيقروا من `values-en`.
 *
 * الحل هنا مركزي عن قصد: تصليح كل موقع لوحده معناه تسعة أماكن لازم تفتكر تعمل نفس
 * الحاجة، والعاشر اللي هيتكتب بكرة هينساها. لف الـ Application بيخلي
 * `applicationContext` نفسه محلّي، فكل موقع بياخد اللغة الصح من غير ما يعرف حاجة.
 *
 * [MarketPrefs.wrapWithStoredLocale] بيقدّم اختيار العميل الصريح على لغة السوق، ولو
 * مفيش اختيار بيرجع للسوق (مصر ← ar-EG) — مش للغة النظام أبداً. يعني أسوأ حالة هنا
 * لغة السوق، مش إنجليزي.
 */
class ZadApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        installCrashHandler()
        runStartupStep("ZadFcmGate.init") { com.example.services.ZadFcmGate.init(this) }
        runStartupStep("RewardedBrainAdManager.initialize") { RewardedBrainAdManager.initialize(this) }
        // كانت مش متندهة خالص — InterstitialAdManager.preload() عمره ما بيتنده استباقياً،
        // فأول إعلان بيني في الجلسة (بعد ٥ تنقلات) كان بيلاقي interstitialAd=null دايماً
        // ويطلب preload وقتها بس، يعني بيتفوّت — الإعلان الفعلي كان بيبان بعد ١٠ تنقلات
        // مش ٥. preload من هنا بيضمن إعلان جاهز من أول تنقلة.
        runStartupStep("InterstitialAdManager.initialize") { com.example.ads.InterstitialAdManager.initialize(this) }
    }

    override fun attachBaseContext(base: Context) {
        // عطل هنا بيحصل قبل أي هاندلر — التطبيق يقع قبل ما يرسم حاجة. لغة النظام أحسن من كده.
        val wrapped = try {
            com.example.data.MarketPrefs.wrapWithStoredLocale(base)
        } catch (e: Throwable) {
            Log.e("ZadApplication", "locale wrap failed — using system locale", e)
            base
        }
        super.attachBaseContext(wrapped)
    }

    /**
     * كان متسجّل في `MainActivity.onCreate` — يعني أي كراش في عملية ماتفتحتش من
     * MainActivity (خدمة اتعاد تشغيلها، ريسيفر، worker، أو عملية شاشة العطل نفسها) كان
     * بيروح لديالوج النظام "التطبيق يستمر في التوقف" من غير ولا سطر stacktrace. من هنا
     * بيغطي كل عملية.
     *
     * - التطبيق قدّام العميل: شاشة [CrashActivity] بالتفاصيل، زي الأول.
     * - في الخلفية، أو شاشة العطل نفسها هي اللي وقعت: هاندلر النظام (مايفتحش شاشة فوق
     *   اللي العميل بيعمله، ومايعملش حلقة).
     * - في الحالتين العطل بيتسجل في [com.example.data.ZadCrashLog] الأول.
     */
    private fun installCrashHandler() {
        // تحت Robolectric الهاندلر ده كان هيقفل JVM التستات نفسه بـ System.exit.
        if (Build.FINGERPRINT == "robolectric") return
        val systemHandler = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try { com.example.data.ZadCrashLog.record(this, throwable) } catch (_: Throwable) {}
            val showCrashScreen = try {
                val state = ActivityManager.RunningAppProcessInfo()
                ActivityManager.getMyMemoryState(state)
                !CrashActivity.shownInThisProcess &&
                    state.importance <= ActivityManager.RunningAppProcessInfo.IMPORTANCE_VISIBLE
            } catch (_: Throwable) {
                false
            }
            if (!showCrashScreen) {
                systemHandler?.uncaughtException(thread, throwable)
                return@setDefaultUncaughtExceptionHandler
            }
            try {
                startActivity(Intent(this, CrashActivity::class.java).apply {
                    putExtra("crash", throwable.stackTraceToString())
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
                })
            } catch (_: Throwable) {
                systemHandler?.uncaughtException(thread, throwable)
                return@setDefaultUncaughtExceptionHandler
            }
            android.os.Process.killProcess(android.os.Process.myPid())
            System.exit(1)
        }
    }
}

/** خطوة إقلاع مش لازمة لرسم الواجهة: فشلها يتسجل ومايقفلش التطبيق. */
internal inline fun runStartupStep(name: String, block: () -> Unit) {
    try {
        block()
    } catch (e: Throwable) {
        Log.e("ZadStartup", "startup step '$name' failed: ${e.message}", e)
    }
}
