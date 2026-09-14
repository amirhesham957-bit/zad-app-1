package com.example.data

import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.ZoneId
import java.time.ZonedDateTime

class AppointmentGroupingTest {

    private val cairo = ZoneId.of("Africa/Cairo")
    private val now = ZonedDateTime.of(2026, 9, 14, 10, 0, 0, 0, cairo)

    private fun appt(id: String, at: ZonedDateTime, status: String = "upcoming") =
        ZadAppointment(id = id, title = id, startsAt = at.toInstant().toString(), status = status)

    @Test
    fun groupsByLocalDayAndKeepsPastAtTheEnd() {
        val groups = groupAppointments(
            listOf(
                appt("later", now.plusDays(10)),
                appt("today", now.plusHours(3)),
                appt("tomorrow", now.plusDays(1)),
                appt("week", now.plusDays(4)),
                appt("pastOnce", now.minusHours(2)),
                appt("done", now.plusHours(5), status = "done"),
                appt("cancelled", now.plusHours(1), status = "cancelled"),
            ),
            now,
        )
        assertEquals(
            listOf(AppointmentGroup.TODAY, AppointmentGroup.TOMORROW, AppointmentGroup.THIS_WEEK, AppointmentGroup.LATER, AppointmentGroup.PAST),
            groups.map { it.first },
        )
        assertEquals(listOf("today"), groups[0].second.map { it.id })
        // اللي فات: الأحدث الأول، والملغي مايظهرش خالص
        assertEquals(listOf("done", "pastOnce"), groups.last().second.map { it.id })
    }

    @Test
    fun lateTonightIsStillToday_andAfterMidnightIsTomorrow() {
        val groups = groupAppointments(
            listOf(
                appt("tonight", now.withHour(23).withMinute(30)),
                appt("afterMidnight", now.plusDays(1).withHour(0).withMinute(15)),
            ),
            now,
        ).toMap()
        assertEquals(listOf("tonight"), groups[AppointmentGroup.TODAY]?.map { it.id })
        assertEquals(listOf("afterMidnight"), groups[AppointmentGroup.TOMORROW]?.map { it.id })
    }

    @Test
    fun parsesOffsetTimestampsFromPostgres() {
        val a = ZadAppointment(id = "x", title = "x", startsAt = "2026-09-15T17:00:00+03:00")
        assertEquals(java.time.Instant.parse("2026-09-15T14:00:00Z"), a.startInstant())
    }
}
