package com.example.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class HabitsSummaryTest {
    @Test
    fun summarizesBehaviorAndOutingsFromRealRowsOnly() {
        val profile = UserBehaviorProfile(
            avgWeeklySpending = 1234.6,
            topSpendingCategories = listOf(BehaviorCategoryTotal("مواصلات", 200.0), BehaviorCategoryTotal("سوبرماركت", 900.0)),
            spendingPatternByWeekday = mapOf("الخميس" to 400.0, "الجمعة" to 650.0),
        )
        val visits = listOf(
            ZadPlaceVisit("2026-09-10T10:00:00Z", "2026-09-10T12:00:00Z", 300.0, "EGP", listOf("كارفور")),
            ZadPlaceVisit("2026-09-11T10:00:00Z", "2026-09-11T12:00:00Z", 100.0, "EGP", listOf("كارفور"), listOf("سعودي")),
            ZadPlaceVisit("2026-09-12T10:00:00Z", "2026-09-12T11:00:00Z", 0.0),
        )
        val s = HabitsSummary.from(profile, visits)
        assertEquals(1235.0, s.avgWeeklySpending!!, 0.0)
        assertEquals(listOf("سوبرماركت", "مواصلات"), s.topCategories)
        assertEquals("الجمعة", s.busiestWeekday)
        assertEquals(3, s.outingsCount)
        assertEquals(200.0, s.avgSpendPerOuting!!, 0.0)
        assertEquals("كارفور", s.topPlaces.first())
    }

    @Test
    fun nothingLearnedYetIsEmpty() {
        assertTrue(HabitsSummary.from(null, emptyList()).isEmpty)
    }
}
