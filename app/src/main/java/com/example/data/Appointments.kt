package com.example.data

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime
import java.time.temporal.ChronoUnit

/**
 * ميعاد أو مشوار أو التزام غير مالي (`zad_appointments`، ميجريشن 20260914004000).
 * الالتزامات المالية (إيجار/قسط) ليها [ZadObligation] من زمان. العقل بيسجّل المواعيد
 * بـ add_appointment من الشات/تليجرام/المكالمة، وزاد بتفكّر بيها بصوتها قبل ميعادها.
 */
@Serializable
data class ZadAppointment(
    val id: String,
    @SerialName("user_id") val userId: String? = null,
    val title: String,
    val kind: String = "personal",
    @SerialName("starts_at") val startsAt: String,
    @SerialName("place_label") val placeLabel: String? = null,
    @SerialName("remind_minutes_before") val remindMinutesBefore: Int = 30,
    val recurrence: String = "once",
    val status: String = "upcoming",
    val source: String = "app",
    val notes: String? = null,
)

/** قيم `kind` زي ما هي في قيد الجدول — بيانات مطابقة، مش نصوص عرض. */
val APPOINTMENT_KINDS = listOf("work", "errand", "medical", "family", "personal", "other")

enum class AppointmentGroup { TODAY, TOMORROW, THIS_WEEK, LATER, PAST }

fun ZadAppointment.startInstant(): Instant? = try {
    Instant.parse(startsAt)
} catch (_: Exception) {
    try { java.time.OffsetDateTime.parse(startsAt).toInstant() } catch (_: Exception) { null }
}

/**
 * تقسيم المواعيد لمجموعات بتوقيت الجهاز. "اللي فات" = ميعاد وقته عدّى أو اتعلّم خلص —
 * بيتعرض آخر حاجة ومقفول، عشان الشاشة تفضل عن اللي جاي. مواعيد ملغية مابتظهرش.
 * صافية (الوقت والمنطقة داخلين كباراميترز) عشان تتختبر.
 */
fun groupAppointments(
    items: List<ZadAppointment>,
    now: ZonedDateTime,
): List<Pair<AppointmentGroup, List<ZadAppointment>>> {
    val zone: ZoneId = now.zone
    val today = now.toLocalDate()
    val grouped = items
        .filter { it.status != "cancelled" }
        .mapNotNull { a -> a.startInstant()?.let { a to it.atZone(zone) } }
        .sortedBy { it.second }
        .groupBy { (a, at) ->
            val days = ChronoUnit.DAYS.between(today, at.toLocalDate())
            when {
                a.status == "done" || at.isBefore(now) -> AppointmentGroup.PAST
                days == 0L -> AppointmentGroup.TODAY
                days == 1L -> AppointmentGroup.TOMORROW
                days <= 7L -> AppointmentGroup.THIS_WEEK
                else -> AppointmentGroup.LATER
            }
        }
    return AppointmentGroup.entries.mapNotNull { g ->
        grouped[g]?.map { it.first }?.let { list ->
            g to if (g == AppointmentGroup.PAST) list.reversed() else list
        }
    }
}
