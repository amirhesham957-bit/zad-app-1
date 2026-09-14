package com.example.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.Instant

/** نفس قواعد النبرة في `zad-brain/weeklyMoney_test.ts` (من غير الهدر). */
class WeekSummaryMathTest {
    private val now = Instant.parse("2026-09-18T15:00:00Z")
    private fun tx(amount: Double, category: String, daysAgo: Long) =
        ZadTransaction(amount = amount, title = category, category = category, createdAt = now.minusSeconds(daysAgo * 86_400L).toString())

    @Test
    fun twentyPercentLessIsProudAndTheTopCategoryIsNamed() {
        val w = WeekSummaryMath.summarize(listOf(tx(500.0, "سوبرماركت", 1), tx(300.0, "مواصلات", 2), tx(1000.0, "سوبرماركت", 9)), now, null)!!
        assertEquals(-20, w.changePct)
        assertEquals("سوبرماركت", w.topCategory)
        assertEquals(WeekSummary.Tone.PROUD, w.tone)
    }

    @Test
    fun aJumpOrOverTheWeeklySliceIsReproach() {
        assertEquals(WeekSummary.Tone.REPROACH, WeekSummaryMath.summarize(listOf(tx(1200.0, "مطاعم", 1), tx(800.0, "x", 10)), now, null)!!.tone)
        assertEquals(WeekSummary.Tone.REPROACH, WeekSummaryMath.summarize(listOf(tx(3000.0, "تسوق", 1)), now, 9000.0)!!.tone)
    }

    @Test
    fun noSpendingThisWeekMeansNoCard() {
        assertNull(WeekSummaryMath.summarize(listOf(tx(100.0, "x", 10)), now, null))
    }
}
