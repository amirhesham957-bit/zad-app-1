package com.example.share

import android.graphics.Bitmap
import androidx.test.core.app.ApplicationProvider
import com.example.data.FamilyMember
import com.example.data.FamilyMemberWithTasbiha
import com.example.data.TasbihaLeaderboard
import com.example.data.TasbihaTree
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.io.File

@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [33], qualifiers = "ar")
class LeaderboardShareCardRenderTest {
    private fun member(id: String, alias: String, score: Int, streak: Int) = FamilyMemberWithTasbiha(
        member = FamilyMember(id = id, userId = id, alias = alias),
        trees = listOf(TasbihaTree(id = "t$id", userId = id, score = score, streakDays = streak)),
        totalScore = score,
    )

    private val family = listOf(member("1", "ماما", 1200, 9), member("2", "بابا", 3400, 3), member("3", "سلمى", 800, 0))

    @Test
    fun entriesAreRankedByScoreWithTheLongestStreakPerMember() {
        val entries = TasbihaLeaderboard.entries(family)
        assertEquals(listOf("بابا", "ماما", "سلمى"), entries.map { it.name })
        assertEquals(listOf(1, 2, 3), entries.map { it.rank })
        assertEquals(9, entries[1].streakDays)
        assertEquals("🥇", TasbihaLeaderboard.medal(1))
    }

    @Test
    fun rendersThePostSizedLeaderboard() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val bmp = LeaderboardShareCard.render(context, TasbihaLeaderboard.entries(family))
        assertEquals(LeaderboardShareCard.WIDTH, bmp.width)
        File("build/outputs/roborazzi").mkdirs()
        File("build/outputs/roborazzi/tasbiha_leaderboard_card.png").outputStream().use { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }
    }
}
