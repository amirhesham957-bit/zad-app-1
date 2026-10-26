package com.aistudio.zad.banklistener

import com.aistudio.zad.banklistener.ListenerWatchdog.Verdict
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * الحارس بيتكلم لما الخدمة تقع بعد ما كانت شغالة — ومش بيزعّج اللي عمره ما فعّلها
 * ولا بيكرر نفس التنبيه أكتر من مرة في اليوم (ZAD_PLAN ٢.١).
 */
class ListenerWatchdogTest {

    private val now = 1_761_000_000_000L
    private val hour = 60L * 60 * 1000

    @Test
    fun `never enabled is not a fault`() {
        assertEquals(Verdict.FINE, ListenerWatchdog.verdict(false, null, null, now))
    }

    @Test
    fun `access taken away after it worked is revoked`() {
        assertEquals(Verdict.REVOKED, ListenerWatchdog.verdict(false, now - hour, now - hour, now))
    }

    @Test
    fun `two days without any notification is stalled`() {
        val old = now - ListenerWatchdog.STALL_AFTER_MS
        assertEquals(Verdict.STALLED, ListenerWatchdog.verdict(true, old, old, now))
    }

    @Test
    fun `a recent notification is fine`() {
        val bound = now - 10 * 24 * hour
        assertEquals(Verdict.FINE, ListenerWatchdog.verdict(true, bound, now - hour, now))
    }

    @Test
    fun `a fresh bind with nothing seen yet is fine`() {
        assertEquals(Verdict.FINE, ListenerWatchdog.verdict(true, now - hour, null, now))
    }

    @Test
    fun `alerts at most once a day`() {
        assertTrue(ListenerWatchdog.shouldAlert(Verdict.STALLED, null, now))
        assertFalse(ListenerWatchdog.shouldAlert(Verdict.STALLED, now - 3 * hour, now))
        assertTrue(ListenerWatchdog.shouldAlert(Verdict.REVOKED, now - ListenerWatchdog.ALERT_EVERY_MS, now))
        assertFalse(ListenerWatchdog.shouldAlert(Verdict.FINE, null, now))
    }
}
