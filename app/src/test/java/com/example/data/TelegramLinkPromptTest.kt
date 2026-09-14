package com.example.data

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** تنبيه ربط تليجرام: أول دخول، تذكير واحد بعد ٣ أيام، وبعد كده مايظهرش تاني. */
class TelegramLinkPromptTest {

    private val day = 24 * 60 * 60 * 1000L

    @Test
    fun `first home open shows the prompt`() {
        assertTrue(TelegramLinkPrompt.shouldShow(timesShown = 0, lastShownAtMs = null, nowMs = 0L))
    }

    @Test
    fun `a dismissed prompt stays quiet inside three days`() {
        assertFalse(TelegramLinkPrompt.shouldShow(timesShown = 1, lastShownAtMs = 0L, nowMs = 2 * day))
    }

    @Test
    fun `one reminder after three days`() {
        assertTrue(TelegramLinkPrompt.shouldShow(timesShown = 1, lastShownAtMs = 0L, nowMs = 3 * day))
    }

    @Test
    fun `never a third time`() {
        assertFalse(TelegramLinkPrompt.shouldShow(timesShown = 2, lastShownAtMs = 0L, nowMs = 30 * day))
    }

    @Test
    fun `a linked account is recorded as done, so it is never shown again`() {
        // recordLinked بيكتب MAX_SHOWS — نفس الحالة دي.
        assertFalse(TelegramLinkPrompt.shouldShow(TelegramLinkPrompt.MAX_SHOWS, lastShownAtMs = null, nowMs = 0L))
    }

    @Test
    fun bannerStaysUntilLinked_andSnoozeHidesItForThreeDaysOnly() {
        val now = 1_800_000_000_000L
        assertTrue(TelegramLinkPrompt.shouldShowBanner(linked = false, hiddenUntilMs = 0L, nowMs = now))
        assertFalse(TelegramLinkPrompt.shouldShowBanner(linked = true, hiddenUntilMs = 0L, nowMs = now))
        // حالة مش معروفة (من غير نت) = مايظهرش — عميل مربوط مايتسألش بالغلط
        assertFalse(TelegramLinkPrompt.shouldShowBanner(linked = null, hiddenUntilMs = 0L, nowMs = now))
        val hiddenUntil = now + TelegramLinkPrompt.BANNER_SNOOZE_MS
        assertFalse(TelegramLinkPrompt.shouldShowBanner(false, hiddenUntil, now + 1))
        assertTrue(TelegramLinkPrompt.shouldShowBanner(false, hiddenUntil, hiddenUntil))
    }

    @Test
    fun linkStatusIsRecheckedAtMostEverySixHours() {
        val now = 1_800_000_000_000L
        assertTrue(TelegramLinkPrompt.statusStale(null, now))
        assertFalse(TelegramLinkPrompt.statusStale(now - 60_000L, now))
        assertTrue(TelegramLinkPrompt.statusStale(now - TelegramLinkPrompt.STATUS_RECHECK_MS, now))
    }
}
