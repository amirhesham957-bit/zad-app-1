package com.example.ui.theme

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.compositeOver
import androidx.compose.ui.graphics.luminance
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * نسبة التباين الفعلية (WCAG 2.x) لأوزان النص التلاتة على الأسطح اللي بتتكتب عليها.
 *
 * قياس ٢٠٢٦-٠٩-١٤ قبل الإصلاح: textTertiary الفاتح كان 2.49:1 على الخلفية — نص رمادي
 * مايتقريش، وده اللي ظهر في لقطات الجهاز كـ"ألوان باهتة". onSurfaceVariant كان 4.72 (على
 * الحافة)، وtextTertiary الغامق 4.46 (تحتها). التست ده بيقفل الحد الأدنى 4.5 (AA لنص عادي)
 * وبيقفل الترتيب — لو حد فتّح لون عشان "يبقى أنعم" هيقع هنا مش عند العميل.
 *
 * ملحوظة: `.copy(alpha = …)` فوق التوكنات دي في الشاشات بيقلل التباين تاني، والتست ده مش
 * بيشوفه — هو بيحمي المصدر بس.
 */
class WcagContrastTest {

    private fun contrast(a: Color, b: Color): Double {
        val la = a.luminance().toDouble()
        val lb = b.luminance().toDouble()
        return (maxOf(la, lb) + 0.05) / (minOf(la, lb) + 0.05)
    }

    private fun assertReadable(name: String, fg: Color, vararg grounds: Pair<String, Color>) {
        grounds.forEach { (groundName, ground) ->
            val ratio = contrast(fg, ground)
            assertTrue("$name على $groundName = ${"%.2f".format(ratio)}:1 (لازم ≥ 4.5)", ratio >= 4.5)
        }
    }

    @Test
    fun lightTextWeightsAreReadable() {
        val grounds = arrayOf("surface" to ZadColorScheme.surface, "background" to ZadColorScheme.background)
        assertReadable("onSurface", ZadColorScheme.onSurface, *grounds)
        assertReadable("onSurfaceVariant", ZadColorScheme.onSurfaceVariant, *grounds)
        assertReadable("textTertiary", ZadExtendedColorsLight.textTertiary, *grounds)
    }

    @Test
    fun darkTextWeightsAreReadable() {
        val grounds = arrayOf("surface" to ZadDarkColorScheme.surface, "background" to ZadDarkColorScheme.background)
        assertReadable("onSurface", ZadDarkColorScheme.onSurface, *grounds)
        assertReadable("onSurfaceVariant", ZadDarkColorScheme.onSurfaceVariant, *grounds)
        assertReadable("textTertiary", ZadExtendedColorsDark.textTertiary, *grounds)
    }

    @Test
    fun textWeightsKeepTheirHierarchy() {
        fun ordered(primary: Color, secondary: Color, tertiary: Color, ground: Color) =
            contrast(primary, ground) > contrast(secondary, ground) && contrast(secondary, ground) > contrast(tertiary, ground)
        assertTrue(ordered(ZadColorScheme.onSurface, ZadColorScheme.onSurfaceVariant, ZadExtendedColorsLight.textTertiary, ZadColorScheme.surface))
        assertTrue(ordered(ZadDarkColorScheme.onSurface, ZadDarkColorScheme.onSurfaceVariant, ZadExtendedColorsDark.textTertiary, ZadDarkColorScheme.surface))
    }

    /** أيقونات شبكة الأقسام: ≥ 3:1 على خلفيتها الشفافة فوق السطح، في الفاتح والغامق. */
    @Test
    fun sectionAccentIconsAreVisibleInBothThemes() {
        ZadSectionAccent.entries.forEach { accent ->
            listOf(false to ZadColorScheme.surface, true to ZadDarkColorScheme.surface).forEach { (dark, surface) ->
                val ground = accent.container(dark).compositeOver(surface)
                val ratio = contrast(accent.content(dark), ground)
                assertTrue("$accent dark=$dark = ${"%.2f".format(ratio)}:1 (لازم ≥ 3)", ratio >= 3.0)
            }
        }
    }

    /** اللوحة الغامقة (قوة الصرف): النص ≥ 4.5 والشريط ≥ 3 فوق خلفيتها الثابتة. */
    @Test
    fun darkPanelAccentsAreReadable() {
        val bg = ZadDarkPanelBackground
        assertTrue(contrast(Color.White, bg) >= 4.5)
        assertTrue(contrast(ZadDarkPanelAccent, bg) >= 4.5)
        listOf(ZadDarkPanelAccent, ZadDarkPanelWarning, ZadDarkPanelDanger, Color(0xFF84CC16)).forEach {
            assertTrue("$it = ${"%.2f".format(contrast(it, bg))}", contrast(it, bg) >= 3.0)
        }
    }
}
