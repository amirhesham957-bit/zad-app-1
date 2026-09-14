package com.example.data

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset
import kotlin.math.floor

/**
 * وضع الطوارئ «مفلس باقي الشهر» (`zad_broke_mode`، ميجريشن 20260914009000).
 *
 * العميل بيقول «أنا مفلس» للعقل (شات/مكالمة/تليجرام → set_broke_mode) أو بيفعّله من شاشة
 * الميزانية. طول ما هو شغال: مصروف اليوم = اللي معاه ÷ الأيام الباقية، اقتراحات الشراء
 * بتختفي، والوصفات من اللي في البيت بس.
 */
@Serializable
data class ZadBrokeMode(
    @SerialName("user_id") val userId: String? = null,
    @SerialName("started_at") val startedAt: String? = null,
    @SerialName("ends_at") val endsAt: String,
    @SerialName("ended_at") val endedAt: String? = null,
    @SerialName("cash_left") val cashLeft: Double? = null,
    @SerialName("daily_cap") val dailyCap: Double? = null,
    val currency: String? = null,
    val source: String = "app",
)

private fun parseInstant(raw: String?): Instant? = raw?.let {
    runCatching { Instant.parse(it) }.getOrNull()
        ?: runCatching { java.time.OffsetDateTime.parse(it).toInstant() }.getOrNull()
}

/** شغال = مااتقفلش ولسه وقته ماخلصش. صف قديم خلص وقته = مش شغال. */
fun ZadBrokeMode?.isActive(now: Instant = Instant.now()): Boolean {
    if (this == null || endedAt != null) return false
    val end = parseInstant(endsAt) ?: return false
    return end.isAfter(now)
}

object BrokeModeMath {
    data class Plan(val cashLeft: Double?, val dailyCap: Double?, val daysLeft: Int, val endsAt: Instant)

    /** نفس `brokeModePlan` في `_shared/brokeMode.ts` — التطبيق والعقل لازم يطلعوا نفس الرقم. */
    fun plan(
        cashLeft: Double?,
        available: Double?,
        limitConfirmed: Boolean,
        daysLeft: Int,
        cycleEnd: LocalDate?,
        now: Instant,
    ): Plan {
        val days = daysLeft.coerceIn(1, 45)
        val cash = when {
            cashLeft != null && cashLeft.isFinite() -> cashLeft.coerceAtLeast(0.0)
            limitConfirmed && available != null && available.isFinite() -> available.coerceAtLeast(0.0)
            else -> null
        }
        val byCycle = cycleEnd?.atStartOfDay()?.toInstant(ZoneOffset.UTC)
        val end = if (byCycle != null && byCycle.isAfter(now.plusSeconds(3600))) byCycle
        else now.plusSeconds(days * 86_400L)
        return Plan(
            cashLeft = cash?.let { kotlin.math.round(it * 100) / 100 },
            dailyCap = cash?.let { floor(it / days) },
            daysLeft = days,
            endsAt = end,
        )
    }

    /** بيانات مطابقة (مش نصوص عرض): حاجات في كل مطبخ مش بتتحسب «شراء». نفس القايمة في السيرفر. */
    private val PANTRY_STAPLES = listOf("ملح", "فلفل", "زيت", "مية", "ماء", "بهارات", "سكر", "كمون")

    fun recipeNeedsNoShopping(missing: List<String>): Boolean =
        missing.all { m -> m.isBlank() || PANTRY_STAPLES.any { m.contains(it) } }
}
