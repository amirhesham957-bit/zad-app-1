package com.aistudio.zad.banklistener

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * إعادة ربط الخدمة ماتبعتش نفس الرسالة تاني — ومن غير ما تبلع رسالة جديدة.
 *
 * بيمشي نفس الخطوات اللي الخدمة بتعملها على [SeenNotifications]: `onNotificationPosted`
 * بيفتكر، و`onListenerConnected` بيمسح الشريط ويفتكر اللي فيه.
 */
class SeenNotificationsTest {

    // مفتاح أندرويد الحقيقي بيخلص بالـ uid، ووقت النشر ملّي ثانية من ١٩٧٠.
    private val key = "0|com.google.android.apps.messaging|1|bdc|10123"
    private val t0 = 1_760_000_000_000L
    private val first = SeenNotifications.id(key, t0)

    @Test
    fun `a message already captured is not captured again on reconnect`() {
        val seen = SeenNotifications.remember(emptySet(), first)

        val scan = SeenNotifications.scan(seen, listOf(first))

        assertEquals(emptyList<String>(), scan.toCapture)
    }

    @Test
    fun `reconnecting twice in a row captures it once`() {
        val firstScan = SeenNotifications.scan(emptySet(), listOf(first))
        val secondScan = SeenNotifications.scan(firstScan.remember, listOf(first))

        assertEquals(listOf(first), firstScan.toCapture)
        assertEquals(emptyList<String>(), secondScan.toCapture)
    }

    @Test
    fun `a message that arrived while unbound is captured on reconnect`() {
        val scan = SeenNotifications.scan(emptySet(), listOf(first))

        assertEquals(listOf(first), scan.toCapture)
    }

    @Test
    fun `the same conversation updated while unbound is captured, not skipped`() {
        // تطبيق الرسايل بيحدّث نفس المفتاح لما رسالة بنك جديدة توصل.
        val seen = SeenNotifications.remember(emptySet(), first)
        val update = SeenNotifications.id(key, t0 + 60_000L)

        val scan = SeenNotifications.scan(seen, listOf(update))

        assertEquals(listOf(update), scan.toCapture)
    }

    @Test
    fun `after a scan only the shade is remembered`() {
        val gone = SeenNotifications.id("dismissed", t0 - 60_000L)
        val seen = SeenNotifications.remember(setOf(gone), first)

        val scan = SeenNotifications.scan(seen, listOf(first))

        assertEquals(setOf(first), scan.remember)
    }

    @Test
    fun `over the cap the oldest by post time go first`() {
        val ids = (1..5).map { SeenNotifications.id("k$it", it * 1_000L) }.shuffled()
        var seen = emptySet<String>()
        ids.forEach { seen = SeenNotifications.remember(seen, it, max = 3) }

        assertEquals(
            setOf("k3|3000", "k4|4000", "k5|5000"),
            seen,
        )
    }

    @Test
    fun `an id from the previous build, key only, is dropped first`() {
        // النسخة اللي فاتت كانت بتحفظ المفتاح لوحده؛ آخره الـ uid، فبيتقري وقت صغير جداً.
        val legacy = key
        val seen = SeenNotifications.remember(setOf(legacy), first, max = 1)

        assertEquals(setOf(first), seen)
        assertTrue(SeenNotifications.scan(setOf(legacy), listOf(first)).toCapture == listOf(first))
    }
}
