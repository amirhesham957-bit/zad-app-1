package com.example.data

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.time.LocalDate
import java.time.ZoneId

/** نفس تواريخ `zad-brain/season_test.ts` — الموبايل والسيرفر لازم يتفقوا على رمضان. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class RamadanCalendarTest {
    private val cairo = ZoneId.of("Africa/Cairo")

    @Test
    fun ummAlQuraRamadan1448() {
        assertFalse(RamadanCalendar.isRamadan(LocalDate.parse("2027-02-07"), cairo))
        assertTrue(RamadanCalendar.isRamadan(LocalDate.parse("2027-02-08"), cairo))
        assertTrue(RamadanCalendar.isRamadan(LocalDate.parse("2027-02-20"), cairo))
        assertFalse(RamadanCalendar.isRamadan(LocalDate.parse("2027-03-09"), cairo))
        assertFalse(RamadanCalendar.isRamadan(LocalDate.parse("2026-09-14"), cairo))
    }
}
