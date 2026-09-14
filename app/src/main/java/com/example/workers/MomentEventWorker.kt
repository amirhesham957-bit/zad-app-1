package com.example.workers

import android.content.Context
import android.util.Log
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import com.example.data.SupabaseRepo
import com.example.data.WakeGreeting

/**
 * بيطلب من العقل لحظة صوت (zad-brain `moment_event`): صباح الخير لما العميل يصحى، أو تذكير
 * التسبيحة. السيرفر هو اللي بيقرر الكلام وبيبعته بصوت زاد (FCM + تليجرام)، ومرة واحدة في
 * اليوم المحلي — فالتكرار هنا (فتح القفل كذا مرة) مابيطلعش أكتر من تحية.
 */
class MomentEventWorker(appContext: Context, params: WorkerParameters) : CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result {
        val moment = inputData.getString(KEY_MOMENT) ?: return Result.failure()
        return try {
            val res = SupabaseRepo.callEdgeFunction("zad-brain", mapOf("action" to "moment_event", "moment" to moment))
            val ok = res["ok"] == true
            Log.d(TAG, "moment_event $moment → ok=$ok status=${res["status"]}")
            if (ok && moment == "morning_greeting") {
                applicationContext.getSharedPreferences("zad_prefs", Context.MODE_PRIVATE).edit()
                    .putString(WakeGreeting.KEY_LAST_GREETING_DATE, java.time.LocalDate.now().toString()).apply()
            }
            if (ok) Result.success() else if (runAttemptCount < 2) Result.retry() else Result.failure()
        } catch (e: Exception) {
            Log.w(TAG, "moment_event $moment failed: ${e.message}")
            if (runAttemptCount < 2) Result.retry() else Result.failure()
        }
    }

    companion object {
        private const val TAG = "MomentEventWorker"
        const val KEY_MOMENT = "moment"

        fun enqueue(context: Context, moment: String) {
            val request = OneTimeWorkRequestBuilder<MomentEventWorker>()
                .setInputData(workDataOf(KEY_MOMENT to moment))
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
                .build()
            // KEEP: كذا فتح للقفل ورا بعض = طلب واحد.
            WorkManager.getInstance(context.applicationContext)
                .enqueueUniqueWork("zad_moment_$moment", ExistingWorkPolicy.KEEP, request)
        }
    }
}
