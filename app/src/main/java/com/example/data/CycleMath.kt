package com.example.data

import java.time.DayOfWeek
import java.time.LocalDate
import java.time.temporal.ChronoUnit

/**
 * Task 25 (PRODUCT_PLAN.md) — دورة الراتب بدل الشهر التقويمي. `cycleStartDay` جاي من
 * `zad_users.cycle_start_day` (nullable — null يعني لسه متكتشفش، فبيرجع لشهر تقويمي عادي،
 * مفيش افتراض إنه يوم ١). كل حساب هنا خالص من التاريخ — مالوش أي علاقة بالمعاملات نفسها،
 * BudgetMath هي اللي بتستخدم النطاق ده على المعاملات (spentInCycle/incomeInCycle).
 */
object CycleMath {

    /**
     * عطلة نهاية الأسبوع بتختلف حسب السوق — أغلب الشرق الأوسط جمعة/سبت، لكن تركيا/المغرب/
     * تونس/الجزائر/لبنان سبت/حد. last_working_day محتاج يعرف يتفاداها.
     */
    fun weekendDays(market: Market): Set<DayOfWeek> = when (market) {
        Market.TURKEY, Market.MOROCCO, Market.TUNISIA, Market.ALGERIA, Market.LEBANON ->
            setOf(DayOfWeek.SATURDAY, DayOfWeek.SUNDAY)
        else -> setOf(DayOfWeek.FRIDAY, DayOfWeek.SATURDAY)
    }

    /**
     * مرتبات الشهر السابق لحد شهرين قدام. النافذة واسعة كده عن قصد: مع
     * `last_working_day` مرتب الشهر الجاي ممكن يرجع لورا جوه الشهر ده (أول
     * الشهر لو وقع سبت بيتصرف الخميس ٣٠)، ومن اليوم ده الدورة بتمشي للمرتب
     * اللي بعده.
     *
     * ده بالظبط اللي بتعمله `zad_period_bounds()` في Postgres. الطريقة القديمة
     * — "مرتب الشهر ده، وإلا اللي قبله" وبعدين النهاية = شهر بعد البداية —
     * كانت **بتنهار** في الحالة دي: البداية والنهاية بيبقوا نفس اليوم، فالدورة
     * تبقى فاضية و`daysLeft` يفضل ينزل تحت الصفر لحد آخر الشهر.
     */
    private fun paydaysAround(
        asOf: LocalDate,
        cycleStartDay: Int,
        cycleAnchor: String,
        market: Market,
    ): List<LocalDate> = (-1..2).map { k ->
        val month = asOf.withDayOfMonth(1).plusMonths(k.toLong())
        anchoredDay(month.year, month.monthValue, cycleStartDay, cycleAnchor, market)
    }

    /** بداية الدورة الحالية (أقرب تاريخ راتب <= asOf) */
    fun cycleStart(asOf: LocalDate, cycleStartDay: Int?, cycleAnchor: String, market: Market): LocalDate {
        if (cycleStartDay == null) return asOf.withDayOfMonth(1)
        // مرتب الشهر اللي فات دايماً قبل أي يوم في الشهر ده، فالقايمة عمرها ما تبقى فاضية.
        return paydaysAround(asOf, cycleStartDay, cycleAnchor, market)
            .filter { !it.isAfter(asOf) }
            .max()
    }

    /** بداية الدورة الجاية (تاريخ الراتب الجاي) — دي حدود "متاح" في Task 26 كمان، مش بس نهاية الدورة الحالية */
    fun cycleEnd(asOf: LocalDate, cycleStartDay: Int?, cycleAnchor: String, market: Market): LocalDate {
        if (cycleStartDay == null) return asOf.withDayOfMonth(1).plusMonths(1)
        // ومرتب بعد شهرين دايماً بعد أي يوم في الشهر ده.
        return paydaysAround(asOf, cycleStartDay, cycleAnchor, market)
            .filter { it.isAfter(asOf) }
            .min()
    }

    /** طول الدورة بالأيام — مش دايماً ٣٠، بيختلف شهر عن شهر خصوصاً مع last_working_day */
    fun cycleLengthDays(cycleStart: LocalDate, cycleEnd: LocalDate): Int =
        ChronoUnit.DAYS.between(cycleStart, cycleEnd).toInt()

    /** شامل النهاردة نفسه — يوم واحد من الدورة خلص فعلاً لو النهاردة هو يوم البداية */
    fun daysElapsed(asOf: LocalDate, cycleStart: LocalDate): Int =
        ChronoUnit.DAYS.between(cycleStart, asOf).toInt() + 1

    fun daysLeft(asOf: LocalDate, cycleEnd: LocalDate): Int =
        ChronoUnit.DAYS.between(asOf, cycleEnd).toInt()

    private fun anchoredDay(year: Int, month: Int, day: Int, anchor: String, market: Market): LocalDate {
        val lastDayOfMonth = LocalDate.of(year, month, 1).lengthOfMonth()
        var date = LocalDate.of(year, month, day.coerceAtMost(lastDayOfMonth))
        if (anchor == "last_working_day") {
            val weekend = weekendDays(market)
            while (date.dayOfWeek in weekend) date = date.minusDays(1)
        }
        return date
    }
}
