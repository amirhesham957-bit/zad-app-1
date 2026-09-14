package com.example.data

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlin.math.roundToInt

/** خروجة من البيت (`zad_place_visits`، 20260914006000) — من غير إحداثيات، وقت وصرف ومحلات بس. */
@Serializable
data class ZadPlaceVisit(
    @SerialName("left_at") val leftAt: String,
    @SerialName("returned_at") val returnedAt: String,
    @SerialName("spent_total") val spentTotal: Double = 0.0,
    val currency: String? = null,
    val merchants: List<String> = emptyList(),
    val stores: List<String> = emptyList(),
)

/**
 * «عاداتك وتحركاتك» — اللي زاد اتعلمته من سلوكك (ملف الصرف الأسبوعي + الخروجات) في شكل يتقري.
 * صافي عشان يتختبر: الأرقام من الصفوف بس، ومفيش استنتاج مالوش مصدر.
 */
data class HabitsSummary(
    val avgWeeklySpending: Double?,
    val topCategories: List<String>,
    val busiestWeekday: String?,
    val subscriptionsMonthly: Double?,
    val outingsCount: Int,
    val avgSpendPerOuting: Double?,
    val topPlaces: List<String>,
) {
    val isEmpty: Boolean
        get() = avgWeeklySpending == null && topCategories.isEmpty() && outingsCount == 0

    companion object {
        fun from(profile: UserBehaviorProfile?, visits: List<ZadPlaceVisit>): HabitsSummary {
            val spendingVisits = visits.filter { it.spentTotal > 0 }
            val places = visits.flatMap { v -> (v.merchants + v.stores).map { it.trim() }.filter { it.isNotEmpty() }.distinct() }
                .groupingBy { it }.eachCount()
                .entries.sortedByDescending { it.value }.take(3).map { it.key }
            return HabitsSummary(
                avgWeeklySpending = profile?.avgWeeklySpending?.takeIf { it > 0 }?.let { it.roundToInt().toDouble() },
                topCategories = profile?.topSpendingCategories.orEmpty().sortedByDescending { it.total }.map { it.category }.filter { it.isNotBlank() }.take(3),
                busiestWeekday = profile?.spendingPatternByWeekday?.filterValues { it > 0 }?.maxByOrNull { it.value }?.key,
                subscriptionsMonthly = profile?.subscriptionLoadMonthly?.takeIf { it > 0 },
                outingsCount = visits.size,
                avgSpendPerOuting = spendingVisits.takeIf { it.isNotEmpty() }?.let { list -> list.sumOf { it.spentTotal } / list.size },
                topPlaces = places,
            )
        }
    }
}
