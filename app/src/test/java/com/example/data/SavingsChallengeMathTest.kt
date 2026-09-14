package com.example.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneId

/** نفس حالات `zad-brain/savingsChallenge_test.ts` + قاعدة صرف اليوم بتاعة التقييم. */
class SavingsChallengeMathTest {
    private val cairo = ZoneId.of("Africa/Cairo")

    @Test
    fun suggestedCapMatchesTheServer() {
        assertEquals(200.0, SavingsChallengeMath.suggestCap(250.0, 400.0)!!, 0.0)
        assertEquals(139.0, SavingsChallengeMath.suggestCap(null, 155.0)!!, 0.0)
        assertNull(SavingsChallengeMath.suggestCap(0.0, -10.0))
    }

    @Test
    fun dayIndexStartsAtOneAndStopsAtTheLength() {
        val ch = ZadSavingsChallenge(id = "c", startedOn = "2026-09-14", lengthDays = 30, dailyCap = 100.0)
        assertEquals(1, SavingsChallengeMath.dayIndex(ch, LocalDate.parse("2026-09-14")))
        assertEquals(30, SavingsChallengeMath.dayIndex(ch, LocalDate.parse("2026-12-01")))
    }

    @Test
    fun todaySpendCountsLocalDayExpensesOnlyAndSkipsExcludedOnes() {
        val txns = listOf(
            // 23:30 القاهرة يوم ١٣ = 20:30Z — مش النهارده
            ZadTransaction(amount = 50.0, title = "a", createdAt = "2026-09-13T20:30:00Z"),
            // 00:30 القاهرة يوم ١٤ = 21:30Z يوم ١٣ — النهارده
            ZadTransaction(amount = 40.0, title = "b", createdAt = "2026-09-13T21:30:00Z"),
            ZadTransaction(amount = 30.0, title = "c", createdAt = "2026-09-14T09:00:00Z"),
            ZadTransaction(amount = 999.0, title = "income", isExpense = false, createdAt = "2026-09-14T09:00:00Z"),
            ZadTransaction(amount = 70.0, title = "excluded", createdAt = "2026-09-14T09:00:00Z", countsTowardBudget = false),
        )
        assertEquals(70.0, SavingsChallengeMath.spentOn(txns, LocalDate.parse("2026-09-14"), cairo), 0.0)
    }
}
