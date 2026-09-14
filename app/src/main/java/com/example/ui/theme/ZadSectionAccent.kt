package com.example.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance

/**
 * لون تمييز لكل قسم في شبكة الأقسام وشيت "المزيد" — بفاتح وغامق.
 *
 * كانت ٢٨ قيمة hex جوه `ZadSectionsGrid.kt` بخلفيات pastel ثابتة: بتكسر حارس
 * `checkNoRawColorsInScreens` (وبالتالي `lintDebug` في CI)، والأسوأ إن مربع pastel فاتح
 * على سطح الوضع الغامق بيبان رقعة. هنا اللون الأمامي -700 في الفاتح و-300 في الغامق،
 * والخلفية شفافية منه فوق السطح نفسه — فبتتظبط مع الثيم لوحدها.
 * [WcagContrastTest] بيقفل إن الأيقونة ≥ 3:1 على خلفيتها في الاتنين (WCAG 1.4.11).
 */
enum class ZadSectionAccent(val light: Color, val dark: Color) {
    Emerald(Color(0xFF047857), Color(0xFF6EE7B7)),
    Amber(Color(0xFFB45309), Color(0xFFFCD34D)),
    Violet(Color(0xFF6D28D9), Color(0xFFC4B5FD)),
    Blue(Color(0xFF1D4ED8), Color(0xFF93C5FD)),
    Indigo(Color(0xFF4338CA), Color(0xFFA5B4FC)),
    Rose(Color(0xFFBE123C), Color(0xFFFDA4AF)),
    Brown(Color(0xFF92400E), Color(0xFFFDBA74)),
    Green(Color(0xFF15803D), Color(0xFF86EFAC)),
    Teal(Color(0xFF0F766E), Color(0xFF5EEAD4)),
    Slate(Color(0xFF334155), Color(0xFFCBD5E1));

    fun content(dark: Boolean): Color = if (dark) this.dark else light
    fun container(dark: Boolean): Color = content(dark).copy(alpha = if (dark) 0.18f else 0.12f)
}

@Composable
private fun isDarkSurface(): Boolean = MaterialTheme.colorScheme.surface.luminance() < 0.5f

val ZadSectionAccent.contentColor: Color @Composable get() = content(isDarkSurface())
val ZadSectionAccent.containerColor: Color @Composable get() = container(isDarkSurface())
