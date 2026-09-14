package com.example.data

import com.example.workers.IftarScheduler
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

class SolarTimesTest {
    private fun minutesUtc(i: Instant) = i.atZone(java.time.ZoneOffset.UTC).let { it.hour * 60 + it.minute }

    @Test
    fun sunsetMatchesKnownMaghribTimes() {
        // مكة ٢٠ فبراير ٢٠٢٧ ≈ ١٨:٢٠ بتوقيتها (15:20Z)، القاهرة ≈ ١٧:٤٦ (15:46Z)
        val mecca = minutesUtc(SolarTimes.sunset(LocalDate.parse("2027-02-20"), 21.4225, 39.8262)!!)
        val cairo = minutesUtc(SolarTimes.sunset(LocalDate.parse("2027-02-20"), 30.0444, 31.2357)!!)
        assertTrue("mecca $mecca", mecca in (15 * 60 + 14)..(15 * 60 + 27))
        assertTrue("cairo $cairo", cairo in (15 * 60 + 40)..(15 * 60 + 53))
    }

    @Test
    fun nextIftarReminderIsTodayBeforeSunsetElseTomorrowAndNeverOutsideRamadan() {
        val zone = ZoneId.of("Africa/Cairo")
        val ramadan = { d: LocalDate -> d >= LocalDate.parse("2027-02-08") && d < LocalDate.parse("2027-03-09") }
        val noon = Instant.parse("2027-02-20T10:00:00Z")
        val today = IftarScheduler.nextReminder(noon, zone, 30.0444, 31.2357, ramadan)!!
        assertEquals(LocalDate.parse("2027-02-20"), today.atZone(zone).toLocalDate())
        val evening = Instant.parse("2027-02-20T16:30:00Z")
        assertEquals(LocalDate.parse("2027-02-21"), IftarScheduler.nextReminder(evening, zone, 30.0444, 31.2357, ramadan)!!.atZone(zone).toLocalDate())
        assertNull(IftarScheduler.nextReminder(Instant.parse("2026-09-14T10:00:00Z"), zone, 30.0444, 31.2357, ramadan))
    }
}
