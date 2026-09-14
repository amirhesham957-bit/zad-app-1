package com.example.share

import android.graphics.Bitmap
import androidx.test.core.app.ApplicationProvider
import com.example.data.WeekSummary
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.io.File

/** الصورة اللي بتتشير: مقاس البوست، ومترسومة فعلاً (مش خلفية فاضية). PNG للمراجعة بالعين. */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [33], qualifiers = "ar")
class WeeklyShareCardRenderTest {
    @Test
    fun rendersAPostSizedCardWithTextOnIt() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val bmp = WeeklyShareCard.render(
            context,
            WeekSummary(spent = 800.0, lastWeekSpent = 1000.0, changePct = -20, topCategory = "سوبرماركت", tone = WeekSummary.Tone.PROUD),
            WeeklyShareCard.Extras(challengeStreak = 7, tasbihaStreak = 5),
        )
        assertEquals(WeeklyShareCard.WIDTH, bmp.width)
        assertEquals(WeeklyShareCard.HEIGHT, bmp.height)
        // نص أبيض اترسم فوق الخلفية الخضرا في منطقة العنوان
        val row = (0 until bmp.width).map { bmp.getPixel(it, 170) }.toSet()
        assertNotEquals(1, row.size)
        File("build/outputs/roborazzi").mkdirs()
        File("build/outputs/roborazzi/weekly_share_card.png").outputStream().use { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }
    }
}
