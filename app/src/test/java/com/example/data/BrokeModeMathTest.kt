package com.example.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant
import java.time.LocalDate

/** نفس حالات `zad-brain/brokeMode_test.ts` — التطبيق والعقل لازم يطلعوا نفس مصروف اليوم. */
class BrokeModeMathTest {
    private val now = Instant.parse("2026-09-14T10:00:00Z")

    @Test
    fun statedCashIsSplitEvenlyOverTheDaysLeft() {
        val plan = BrokeModeMath.plan(300.0, 5000.0, true, 16, LocalDate.parse("2026-10-01"), now)
        assertEquals(18.0, plan.dailyCap!!, 0.0)
        assertEquals(Instant.parse("2026-10-01T00:00:00Z"), plan.endsAt)
    }

    @Test
    fun unconfirmedBalanceGivesNoDailyNumber() {
        val plan = BrokeModeMath.plan(null, 999.0, false, 10, null, now)
        assertNull(plan.dailyCap)
        assertEquals(now.plusSeconds(10 * 86_400L), plan.endsAt)
    }

    @Test
    fun negativeAvailableIsZeroNotNegative() {
        assertEquals(0.0, BrokeModeMath.plan(null, -200.0, true, 8, null, now).dailyCap!!, 0.0)
    }

    @Test
    fun activeOnlyUntilItEndsOrIsLeft() {
        assertTrue(ZadBrokeMode(endsAt = "2026-09-20T00:00:00+00:00").isActive(now))
        assertFalse(ZadBrokeMode(endsAt = "2026-09-10T00:00:00Z").isActive(now))
        assertFalse(ZadBrokeMode(endsAt = "2026-09-20T00:00:00Z", endedAt = "2026-09-13T00:00:00Z").isActive(now))
        assertFalse((null as ZadBrokeMode?).isActive(now))
    }

    @Test
    fun recipesMayUseStaplesButNothingToBuy() {
        assertTrue(BrokeModeMath.recipeNeedsNoShopping(listOf("ملح", "زيت ذرة")))
        assertFalse(BrokeModeMath.recipeNeedsNoShopping(listOf("فراخ")))
    }
}
