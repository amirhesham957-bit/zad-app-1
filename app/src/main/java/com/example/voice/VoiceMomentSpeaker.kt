package com.example.voice

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.work.CoroutineWorker
import androidx.work.ForegroundInfo
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.OutOfQuotaPolicy
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume

/**
 * لحظة صوت وصلت من السيرفر (`zad_voice_moments` عبر FCM data-only): زاد بتقولها بصوتها.
 *
 * قرار المستخدم ٢٠٢٦-٠٩-١٤: "تتكلم لوحدها" — بس بعقل: الشاشة مفتوحة والموبايل مش صامت
 * والتنبيهات الصوتية مش مقفولة من الإعدادات. غير كده الإشعار بيفضل وعليه زرار "اسمع زاد"،
 * والفويس بيكون وصل تليجرام كمان.
 *
 * الكلام في Worker مستعجل مش جوه onMessageReceived: FCM بيدي الخدمة ثواني قليلة، وتوليد
 * الصوت + تشغيله بياخد ١٠–٢٠ ثانية — من غير الـWorker العملية ممكن تتقتل في نص الجملة.
 */
object VoiceMomentSpeaker {

    private const val TAG = "VoiceMomentSpeaker"
    const val EXTRA_SPEECH = "speech"
    const val EXTRA_MOMENT = "moment"

    /** يتكلم تلقائي دلوقتي؟ منطق صافي عشان يتختبر من غير جهاز. */
    fun shouldAutoSpeak(screenOn: Boolean, ringerMode: Int, spokenAlertsEnabled: Boolean): Boolean =
        spokenAlertsEnabled && screenOn && ringerMode == AudioManager.RINGER_MODE_NORMAL

    fun canAutoSpeakNow(context: Context): Boolean {
        val power = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        val audio = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
        return shouldAutoSpeak(
            screenOn = power?.isInteractive == true,
            ringerMode = audio?.ringerMode ?: AudioManager.RINGER_MODE_SILENT,
            spokenAlertsEnabled = com.example.ui.screens.AlertPrefs.isEnabled(
                context, com.example.ui.screens.AlertPrefs.KEY_VOICE_SPOKEN_ALERTS
            ),
        )
    }

    fun enqueue(context: Context, speech: String, moment: String?) {
        if (speech.isBlank()) return
        val request = OneTimeWorkRequestBuilder<SpeakWorker>()
            .setInputData(workDataOf(EXTRA_SPEECH to speech.take(600), EXTRA_MOMENT to moment))
            .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
            .build()
        WorkManager.getInstance(context.applicationContext).enqueue(request)
        Log.d(TAG, "voice moment queued (${moment ?: "no moment"})")
    }

    class SpeakWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
        override suspend fun doWork(): Result {
            val speech = inputData.getString(EXTRA_SPEECH).orEmpty()
            val moment = inputData.getString(EXTRA_MOMENT)
            if (speech.isBlank()) return Result.success()
            suspendCancellableCoroutine { cont ->
                ZadAlertSpeaker.speakAlert(applicationContext, speech, moment) {
                    if (cont.isActive) cont.resume(Unit)
                }
            }
            return Result.success()
        }

        /** أندرويد أقدم من 12 بيشغّل الشغل المستعجل كخدمة أمامية ومحتاج إشعار ليها. */
        override suspend fun getForegroundInfo(): ForegroundInfo {
            val channel = com.example.services.ZadFirebaseMessagingService.AGENT_CHANNEL
            val notification = NotificationCompat.Builder(applicationContext, channel)
                .setSmallIcon(com.example.R.drawable.ic_launcher_foreground)
                .setContentTitle(applicationContext.getString(com.example.R.string.voice_moment_speaking))
                .setSilent(true)
                .build()
            return ForegroundInfo(0x5A_D0_01, notification)
        }
    }

    /** زرار "اسمع زاد" على الإشعار. */
    class ListenReceiver : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val speech = intent.getStringExtra(EXTRA_SPEECH).orEmpty()
            enqueue(context, speech, intent.getStringExtra(EXTRA_MOMENT))
            val notificationId = intent.getIntExtra("notification_id", 0)
            if (notificationId != 0) {
                (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(notificationId)
            }
        }
    }
}
