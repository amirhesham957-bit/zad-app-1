package com.example.data

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit
import kotlin.math.floor
import kotlin.math.roundToInt

/**
 * تحدي ٣٠ يوم توفير (`zad_savings_challenges`، ميجريشن 20260914010000). العدادات (السلسلة
 * والأيام) بيكتبها تقييم السيرفر كل صباح؛ الموبايل بيقرا ويعرض صرف النهارده الحي بس.
 */
@Serializable
data class ZadSavingsChallenge(
    val id: String,
    @SerialName("started_on") val startedOn: String,
    @SerialName("length_days") val lengthDays: Int = 30,
    @SerialName("daily_cap") val dailyCap: Double,
    val currency: String? = null,
    val status: String = "active",
    @SerialName("days_won") val daysWon: Int = 0,
    @SerialName("days_lost") val daysLost: Int = 0,
    val streak: Int = 0,
    @SerialName("best_streak") val bestStreak: Int = 0,
)

object SavingsChallengeMath {
    /** نفس `suggestChallengeCap` في `_shared/savingsChallenge.ts`. */
    fun suggestCap(avgDailySpend: Double?, dailyAllowanceLeft: Double?): Double? = when {
        avgDailySpend != null && avgDailySpend > 0 -> (avgDailySpend * 0.8).roundToInt().coerceAtLeast(1).toDouble()
        dailyAllowanceLeft != null && dailyAllowanceLeft > 0 -> floor(dailyAllowanceLeft * 0.9).coerceAtLeast(1.0)
        else -> null
    }

    /** اليوم رقم كام (١ = يوم البداية)، مقصوص على طول التحدي. */
    fun dayIndex(challenge: ZadSavingsChallenge, today: LocalDate): Int {
        val start = runCatching { LocalDate.parse(challenge.startedOn) }.getOrNull() ?: return 1
        return (ChronoUnit.DAYS.between(start, today).toInt() + 1).coerceIn(1, challenge.lengthDays)
    }

    private fun localDate(raw: String?, zone: ZoneId): LocalDate? = raw?.let {
        (runCatching { Instant.parse(it) }.getOrNull()
            ?: runCatching { java.time.OffsetDateTime.parse(it).toInstant() }.getOrNull())
            ?.atZone(zone)?.toLocalDate()
    }

    /** صرف النهارده بنفس قاعدة التقييم: مصروف بس، ومن غير اللي العميل استثناه من الميزانية. */
    fun spentOn(transactions: List<ZadTransaction>, day: LocalDate, zone: ZoneId): Double =
        transactions
            .filter { it.txnKind == "expense" && it.countsTowardBudget != false && localDate(it.createdAt, zone) == day }
            .sumOf { kotlin.math.abs(it.amount) }

    /** متوسط الصرف اليومي آخر ٣٠ يوم — أساس السقف المقترح. */
    fun averageDailySpend(transactions: List<ZadTransaction>, today: LocalDate, zone: ZoneId): Double? {
        val from = today.minusDays(30)
        val total = transactions
            .filter { it.txnKind == "expense" && it.countsTowardBudget != false }
            .filter { t -> localDate(t.createdAt, zone)?.let { !it.isBefore(from) && !it.isAfter(today) } == true }
            .sumOf { kotlin.math.abs(it.amount) }
        return if (total > 0) total / 30 else null
    }
}
