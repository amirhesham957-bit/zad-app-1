package com.example.data

import android.icu.util.IslamicCalendar
import android.icu.util.TimeZone
import android.icu.util.ULocale
import java.time.LocalDate
import java.time.ZoneId

/**
 * رمضان بتقويم أم القرى على الموبايل (android.icu، متاح من API 24 = minSdk). نفس حساب السيرفر
 * (`_shared/season.ts`)، والسيرفر هو اللي بيتأكد تاني قبل ما يقول أي حاجة.
 */
object RamadanCalendar {
    private const val RAMADAN_MONTH_INDEX = 8 // IslamicCalendar: محرم = 0

    fun isRamadan(date: LocalDate, zone: ZoneId = ZoneId.systemDefault()): Boolean = hijri(date, zone)?.first == RAMADAN_MONTH_INDEX

    /** (شهر من 0، يوم) للتاريخ ده الساعة ١٢ الضهر بتوقيت المنطقة. */
    fun hijri(date: LocalDate, zone: ZoneId): Pair<Int, Int>? = try {
        val cal = IslamicCalendar(TimeZone.getTimeZone(zone.id), ULocale.ROOT)
        cal.calculationType = IslamicCalendar.CalculationType.ISLAMIC_UMALQURA
        cal.timeInMillis = date.atTime(12, 0).atZone(zone).toInstant().toEpochMilli()
        cal.get(IslamicCalendar.MONTH) to cal.get(IslamicCalendar.DAY_OF_MONTH)
    } catch (_: Throwable) {
        null
    }
}
