package com.example.data

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset
import kotlin.math.PI
import kotlin.math.acos
import kotlin.math.cos
import kotlin.math.roundToLong
import kotlin.math.sin
import kotlin.math.tan

/**
 * وقت المغرب (غروب الشمس) من خط العرض والطول — معادلات NOAA المختصرة، بدقة دقيقة أو اتنين.
 * بيتحسب على الموبايل من مكان البيت ([HomePlace]) عشان الإحداثيات ماتطلعش برّه الجهاز.
 * متاكد منه قدام مواقيت معروفة: مكة ٢٠ فبراير ٢٠٢٧ ≈ ١٨:٢٠ بتوقيتها، القاهرة ≈ ١٧:٤٦.
 */
object SolarTimes {
    fun sunset(date: LocalDate, lat: Double, lon: Double): Instant? {
        val g = 2 * PI / 365 * (date.dayOfYear - 1)
        val eqTime = 229.18 * (0.000075 + 0.001868 * cos(g) - 0.032077 * sin(g) - 0.014615 * cos(2 * g) - 0.040849 * sin(2 * g))
        val decl = 0.006918 - 0.399912 * cos(g) + 0.070257 * sin(g) - 0.006758 * cos(2 * g) +
            0.000907 * sin(2 * g) - 0.002697 * cos(3 * g) + 0.00148 * sin(3 * g)
        val latR = Math.toRadians(lat)
        val cosHa = cos(Math.toRadians(90.833)) / (cos(latR) * cos(decl)) - tan(latR) * tan(decl)
        if (cosHa < -1 || cosHa > 1) return null // شمس مابتغربش/مابتطلعش (قطبي)
        val ha = Math.toDegrees(acos(cosHa))
        val minutesUtc = 720 - 4 * (lon - ha) - eqTime
        return date.atStartOfDay(ZoneOffset.UTC).toInstant().plusSeconds((minutesUtc * 60).roundToLong())
    }
}
