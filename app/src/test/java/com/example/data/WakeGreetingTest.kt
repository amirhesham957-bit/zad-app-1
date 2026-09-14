package com.example.data

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.ZoneId
import java.time.ZonedDateTime

class WakeGreetingTest {
    private val cairo = ZoneId.of("Africa/Cairo")
    private fun at(h: Int, m: Int = 0) = ZonedDateTime.of(2026, 9, 14, h, m, 0, 0, cairo)
    private fun hoursBefore(now: ZonedDateTime, h: Long) = now.minusHours(h).toInstant().toEpochMilli()

    @Test
    fun firstUnlockInTheMorningAfterSleepGreets() {
        val now = at(7, 30)
        assertTrue(WakeGreeting.shouldGreet(hoursBefore(now, 7), null, now))
    }

    @Test
    fun aShortScreenOffIsNotSleep() {
        val now = at(9)
        assertFalse(WakeGreeting.shouldGreet(hoursBefore(now, 1), null, now))
    }

    @Test
    fun onlyOncePerDayAndOnlyInTheMorning() {
        val now = at(8)
        assertFalse(WakeGreeting.shouldGreet(hoursBefore(now, 8), "2026-09-14", now))
        assertTrue(WakeGreeting.shouldGreet(hoursBefore(now, 8), "2026-09-13", now))
        val night = at(2)
        assertFalse(WakeGreeting.shouldGreet(hoursBefore(night, 5), null, night))
        val noon = at(12)
        assertFalse(WakeGreeting.shouldGreet(hoursBefore(noon, 5), null, noon))
    }

    @Test
    fun noScreenOffRecordedMeansNoGuess() {
        assertFalse(WakeGreeting.shouldGreet(null, null, at(8)))
    }
}
