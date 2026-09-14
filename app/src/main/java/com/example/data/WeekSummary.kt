package com.example.data

import java.time.Instant
import java.time.ZoneId
import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * «أسبوعك مع زاد» على الموبايل — الكارت اللي بيتشير. نفس قواعد النبرة بتاعة تقرير الجمعة
 * الصوتي (`voiceMoments.summarizeWeek`) من غير الهدر (مش متاح هنا). الكارت المتشير مافيهوش
 * ولا مبلغ عن قصد: نسبة التغيير وأكتر فئة والسلاسل بس — الناس بتشير إنجاز، مش كشف حساب.
 */
data class WeekSummary(
    val spent: Double,
    val lastWeekSpent: Double,
    /** سالب = صرف أقل. null = مفيش أسبوع قبله يتقارن بيه. */
    val changePct: Int?,
    val topCategory: String?,
    val tone: Tone,
) {
    enum class Tone { PROUD, REPROACH, NEUTRAL }
}

object WeekSummaryMath {
    private fun instantOf(raw: String?): Instant? = raw?.let {
        runCatching { Instant.parse(it) }.getOrNull()
            ?: runCatching { java.time.OffsetDateTime.parse(it).toInstant() }.getOrNull()
    }

    fun summarize(transactions: List<ZadTransaction>, now: Instant, monthlyLimit: Double?): WeekSummary? {
        val weekAgo = now.minusSeconds(7 * 86_400L)
        val twoWeeksAgo = now.minusSeconds(14 * 86_400L)
        val expenses = transactions.filter { it.txnKind == "expense" && it.countsTowardBudget != false }
            .mapNotNull { t -> instantOf(t.createdAt)?.let { t to it } }
            .filter { (_, at) -> !at.isBefore(twoWeeksAgo) && at.isBefore(now) }
        val thisWeek = expenses.filter { (_, at) -> !at.isBefore(weekAgo) }.map { it.first }
        val lastWeek = expenses.filter { (_, at) -> at.isBefore(weekAgo) }.map { it.first }
        val spent = thisWeek.sumOf { abs(it.amount) }.roundToInt().toDouble()
        if (spent <= 0) return null
        val last = lastWeek.sumOf { abs(it.amount) }.roundToInt().toDouble()
        val top = thisWeek.groupBy { it.category?.takeIf { c -> c.isNotBlank() } }
            .mapValues { (_, v) -> v.sumOf { abs(it.amount) } }
            .filterKeys { it != null }
            .maxByOrNull { it.value }?.key
        val weeklyBudget = monthlyLimit?.takeIf { it > 0 }?.let { (it * 7 / 30).roundToInt().toDouble() }
        val changePct = if (last > 0) ((spent - last) / last * 100).roundToInt() else null

        val lessThanLast = last > 0 && spent <= last * 0.9
        val muchMore = last > 0 && spent >= last * 1.15
        val underBudget = weeklyBudget != null && spent <= weeklyBudget * 0.85
        val overBudget = weeklyBudget != null && spent > weeklyBudget * 1.05
        val tone = when {
            muchMore || overBudget -> WeekSummary.Tone.REPROACH
            lessThanLast || underBudget -> WeekSummary.Tone.PROUD
            else -> WeekSummary.Tone.NEUTRAL
        }
        return WeekSummary(spent, last, changePct, top, tone)
    }

    @Suppress("unused")
    fun zone(): ZoneId = ZoneId.systemDefault()
}
