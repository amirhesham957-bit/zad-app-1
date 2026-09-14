package com.example.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class HomePlaceTest {
    private val home = 30.0444 to 31.2357

    @Test
    fun oneNightIsNotEnough_twoNightsNearbyAreHome() {
        assertNull(HomePlace.learnHome(listOf(HomePlace.Sample(home.first, home.second, "2026-09-13"))))
        val learned = HomePlace.learnHome(listOf(
            HomePlace.Sample(home.first, home.second, "2026-09-13"),
            HomePlace.Sample(home.first + 0.0003, home.second, "2026-09-14"), // ~33m
        ))
        assertNotNull(learned)
        assertTrue(HomePlace.distanceMeters(learned!!.first, learned.second, home.first, home.second) < 30)
    }

    @Test
    fun aNightSomewhereElseDoesNotMoveHomeByItself() {
        val samples = listOf(
            HomePlace.Sample(home.first, home.second, "2026-09-12"),
            HomePlace.Sample(home.first, home.second, "2026-09-13"),
            HomePlace.Sample(home.first + 0.05, home.second, "2026-09-14"), // ~5.5km — ليلة عند قرايب
        )
        assertNull(HomePlace.learnHome(samples))
    }

    @Test
    fun onlyRealOutingsCount() {
        val now = 1_800_000_000_000L
        assertFalse(HomePlace.isOuting(null, now))
        assertFalse(HomePlace.isOuting(now - 20 * 60_000L, now))          // نزل تحت البيت
        assertTrue(HomePlace.isOuting(now - 2 * 60 * 60_000L, now))       // خروجة
        assertFalse(HomePlace.isOuting(now - 30L * 60 * 60_000L, now))    // سفر / رجوع اتفقد
    }

    @Test
    fun distanceIsSane() {
        assertEquals(111_195.0, HomePlace.distanceMeters(0.0, 0.0, 1.0, 0.0), 200.0)
    }
}
