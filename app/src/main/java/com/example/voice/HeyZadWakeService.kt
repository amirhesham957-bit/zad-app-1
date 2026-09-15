package com.example.voice

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.example.MainActivity
import com.example.R
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel

/**
 * "Hey Zad" — استماع دائم خفيف لكلمة السحر.
 *
 * كيفية العمل (بدون مكتبات مدفوعة):
 * - SpeechRecognizer دائم بحلقة إعادة تشغيل ذاتية: كل نتيجة تُحلَّل محليًا بحثًا عن
 *   كلمات التنبيه ("hey zad / يا زاد / أزاد"). لو وجدت → نبّه الواجهة (WakeBus) وافتح
 *   شاشة الصوت. لو مفيش → كمّل استماع من جديد.
 * - Foreground service بإشعار هادئ عشان أندرويد مياكلش الخدمة.
 * - ما بيبعتش أي حاجة للشبكة بنفسه — التعرف كله on-device/جوجل STT المجاني، والطلب
 *   الفعلي بيحصل بس لما المستخدم ينطق الطلب بعد الـ wake word في شاشة الصوت العادية.
 */
class HeyZadWakeService : Service() {

    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var recognizer: SpeechRecognizer? = null
    private var running = false
    @Volatile private var paused = false

    override fun onBind(intent: Intent?): IBinder? = null

    /** false = النظام رفض startForeground، والخدمة بتقفل نفسها بدل ما توقّع التطبيق. */
    private var foregroundStarted = false

    override fun onCreate() {
        super.onCreate()
        foregroundStarted = startForegroundWithNotification()
        if (foregroundStarted) startWakeLoop() else stopSelf()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // من غير START_NOT_STICKY هنا النظام كان هيعيد تشغيل الخدمة من الخلفية ويقع
        // في نفس الرفض تاني — حلقة "التطبيق يستمر في التوقف".
        if (!foregroundStarted) {
            stopSelf()
            return START_NOT_STICKY
        }
        when (intent?.action) {
            ACTION_STOP -> {
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_PAUSE -> {
                // شاشة الصوت مفتوحة — نسيب المايك ليها لوحدها
                paused = true
                try { recognizer?.stopListening() } catch (_: Exception) {}
                return START_STICKY
            }
            ACTION_RESUME -> {
                paused = false
                if (running) rearm()
                return START_STICKY
            }
        }
        return START_STICKY
    }

    /**
     * كراش الإقلاع على أندرويد ١٤+ (2026-09-15، بيلد 940e1554): `WakePrefs` مفعّلة افتراضيًا،
     * فـ`MainActivity` بتشغّل الخدمة من أول فتحة — قبل ما حد يطلب RECORD_AUDIO. مع
     * targetSdk 34+ النظام بيرمي SecurityException من `startForeground(type=MICROPHONE)` لو
     * الإذن مش ممنوح، أو لو الخدمة اتشغلت من الخلفية (إعادة تشغيل START_STICKY). الرمية
     * بتحصل هنا جوه onCreate الخدمة، فالـ try/catch حوالين `start()` في MainActivity
     * ماكانش يقدر يمسكها. أندرويد ≤ ١٣ مابيطبّقش الشرط ده، وده سبب إنه وقع على أجهزة وأجهزة لأ.
     */
    private fun startForegroundWithNotification(): Boolean {
        if (!hasMicPermission(this)) {
            Log.w(TAG, "RECORD_AUDIO not granted — wake service not started")
            return false
        }
        return try {
            showForegroundNotification()
            true
        } catch (e: Exception) {
            // SecurityException (أندرويد ١٤+) أو ForegroundServiceStartNotAllowedException (١٢+)
            Log.w(TAG, "startForeground refused: ${e.message}")
            false
        }
    }

    private fun showForegroundNotification() {
        val channelId = "zad_wake_word"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(
                NotificationChannel(channelId, "استماع زاد المستمر", NotificationManager.IMPORTANCE_MIN).apply {
                    setShowBadge(false)
                }
            )
        }
        val intent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java).apply { putExtra("open_voice", true) },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notification: Notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle(getString(R.string.wake_service_title))
            .setContentText(getString(R.string.wake_service_body))
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setContentIntent(intent)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(WAKE_NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
        } else {
            startForeground(WAKE_NOTIFICATION_ID, notification)
        }
    }

    private fun startWakeLoop() {
        if (!SpeechRecognizer.isRecognitionAvailable(this)) return
        running = true
        armRecognizer()
    }

    /** عمود صفر: الالتقاط في onPartialResults لوحده مش كفاية — أجهزة كتير بتبعت
     *  partials فاضية للعبارت القصيرة، فالكلمة السحرية "مش بتتسمع" والحلقة بتفضل تدور.
     *  البديل: نفحص partials + النتيجة النهائية، وguard واحد يمنع الطلبات المكررة. */
    @Volatile private var wakeFired = false
    @Volatile private var consecutiveErrors = 0

    private fun handleTranscript(text: String?) {
        if (wakeFired) return
        val t = text?.lowercase()?.trim() ?: return
        if (WAKE_PHRASES.none { t.contains(it) }) return
        wakeFired = true
        // نبّه بالأذن — صفتة قصيرة لطيفة (مش مزعجة) عشان العميل يعرف إنه اتسمع
        try { ZadCutePetSoundFx.play(ZadCutePetSoundFx.PetSound.MeowChirp, 0.35f) } catch (_: Exception) {}
        val launch = Intent(this@HeyZadWakeService, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra("open_voice", true)
        }
        startActivity(launch)
    }

    private fun armRecognizer() {
        if (!running || paused) return
        wakeFired = false
        try { recognizer?.destroy() } catch (_: Exception) {}
        recognizer = SpeechRecognizer.createSpeechRecognizer(this).apply {
            setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: android.os.Bundle?) { consecutiveErrors = 0 }
                override fun onBeginningOfSpeech() {}
                override fun onRmsChanged(rmsdB: Float) {}
                override fun onBufferReceived(buffer: ByteArray?) {}
                override fun onEndOfSpeech() {}
                override fun onPartialResults(partialResults: android.os.Bundle?) {
                    handleTranscript(
                        partialResults
                            ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                            ?.firstOrNull()
                    )
                }
                override fun onResults(results: android.os.Bundle?) {
                    handleTranscript(
                        results
                            ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                            ?.firstOrNull()
                    )
                    rearm()
                }
                override fun onError(error: Int) {
                    // أخطاء 6/7 (مهلة صمت/لا تطابق) طبيعية في حلقة استماع دائمة —
                    // لكن لو اتكررت ورا بعض يبقى فيه مشكلة أجهزة: نبطّئ الحلقة تدريجياً
                    // عشان ما نستهلكش بطارية وما يتقتلش الـ service.
                    consecutiveErrors++
                    rearm()
                }
                override fun onEvent(eventType: Int, params: android.os.Bundle?) {}
            })
            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, "ar-EG")
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, "ar-EG")
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 1500L)
            }
            try { startListening(intent) } catch (_: Exception) { rearm() }
        }
    }

    /** إعادة تسليح بعد كل نتيجة/خطأ — مع مهلة قصيرة عشان ما نلفش الحلقة بسرعة جنونية. */
    private fun rearm() {
        if (!running || paused) return
        // backoff تدريجي: 400ms عادي، ولحد 4s لو الأخطاء اتكررت — الحلقة تفضل حية
        val delayMs = if (consecutiveErrors >= 5) 4000L else if (consecutiveErrors >= 2) 1200L else 400L
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            if (wakeFired) {
                // كلمة السحر اتقالت والشاشة اتفتحت — صفّر الحالة وكمّل الاستماع بعد ما الشاشة تستقر
                consecutiveErrors = 0
                wakeFired = false
            }
            armRecognizer()
        }, delayMs)
    }

    override fun onDestroy() {
        running = false
        serviceScope.cancel()
        try { recognizer?.destroy() } catch (_: Exception) {}
        super.onDestroy()
    }

    companion object {
        const val WAKE_NOTIFICATION_ID = 4711
        const val ACTION_STOP = "com.example.voice.STOP_WAKE"
        const val ACTION_PAUSE = "com.example.voice.PAUSE_WAKE"
        const val ACTION_RESUME = "com.example.voice.RESUME_WAKE"

        /** كل الصيغ المقبولة لكلمة التنبيه — كلمات مميزة بس، ممنوع كلمات قصيرة
         *  تتشالف في الكلام العادي (كان "ازاد" بيتكتشف من أي حرف زاد في جملة). */
        val WAKE_PHRASES = listOf(
            "hey zad", "hey زاد", "hi zad", "يا زاد", "ازيك يا زاد", "هي زاد"
        )

        private const val TAG = "HeyZadWakeService"

        fun hasMicPermission(context: Context): Boolean =
            ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
                PackageManager.PERMISSION_GRANTED

        /**
         * مابتشغلش حاجة من غير إذن المايك: startForegroundService بيلزم الخدمة تنادي
         * startForeground، واللي هي مش هتقدر تعمله من غير الإذن — والنظام بيوقّع التطبيق لو
         * الخدمة وقفت قبلها. الخدمة بتشتغل لوحدها أول ما الإذن يتمنح (resume() من شاشة
         * الصوت، أو الفتحة الجاية).
         */
        fun start(context: Context) {
            if (!hasMicPermission(context)) return
            val intent = Intent(context, HeyZadWakeService::class.java)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: Exception) {
                Log.w(TAG, "wake service start refused: ${e.message}")
            }
        }

        fun stop(context: Context) {
            context.startService(Intent(context, HeyZadWakeService::class.java).apply { action = ACTION_STOP })
        }

        /** شاشة الصوت مفتوحة — الخدمة تسيب المايك. */
        fun pause(context: Context) {
            try {
                context.startService(Intent(context, HeyZadWakeService::class.java).apply { action = ACTION_PAUSE })
            } catch (_: Exception) {}
        }

        /** شاشة الصوت اتقفلت — الخدمة ترجع تستمع. */
        fun resume(context: Context) {
            try {
                context.startService(Intent(context, HeyZadWakeService::class.java).apply { action = ACTION_RESUME })
            } catch (_: Exception) {}
        }
    }
}
