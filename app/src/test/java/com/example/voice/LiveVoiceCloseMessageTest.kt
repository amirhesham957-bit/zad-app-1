package com.example.voice

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * المكالمة الحية على جهاز حقيقي كانت بتقول "تعذّر الاتصال" لكل سبب، والسبب الفعلي كان
 * رصيد صوت = صفر. الأكواد دي هي الطريقة الوحيدة اللي السيرفر يقدر يوصّل بيها السبب،
 * فالتست بيقفل إن كل كود ليه رسالة مختلفة، وإن الإغلاق الطبيعي مايتحسبش خطأ.
 */
class LiveVoiceCloseMessageTest {

    @Test
    fun normalCloseIsNotAnError() {
        assertNull(liveVoiceCloseMessage(1000, "session ended"))
        assertNull(liveVoiceCloseMessage(1001, ""))
    }

    @Test
    fun codesMatchTheServerProtocolFile() {
        // supabase/functions/zad-voice-live/protocol.ts
        assertEquals(4401, LIVE_CLOSE_UNAUTHORIZED)
        assertEquals(4402, LIVE_CLOSE_ENTITLEMENT)
        assertEquals(4502, LIVE_CLOSE_UPSTREAM_ENDED)
        assertEquals(4503, LIVE_CLOSE_PROVIDER_UNAVAILABLE)
    }

    @Test
    fun eachRejectionReasonHasItsOwnMessage() {
        val messages = listOf(
            liveVoiceCloseMessage(LIVE_CLOSE_UNAUTHORIZED, "unauthorized"),
            liveVoiceCloseMessage(LIVE_CLOSE_ENTITLEMENT, "quota_exhausted"),
            liveVoiceCloseMessage(LIVE_CLOSE_PROVIDER_UNAVAILABLE, "provider_not_configured"),
            liveVoiceCloseMessage(LIVE_CLOSE_UPSTREAM_ENDED, "upstream 1008: model not found"),
        )
        messages.forEach { assertNotNull(it) }
        assertEquals(messages.size, messages.toSet().size)
    }

    @Test
    fun upstreamQuotaIsToldApartFromOtherUpstreamFailures() {
        val quota = liveVoiceCloseMessage(LIVE_CLOSE_UPSTREAM_ENDED, "upstream 1011: Resource has been exhausted (check quota)")
        val other = liveVoiceCloseMessage(LIVE_CLOSE_UPSTREAM_ENDED, "upstream 1007: invalid setup")
        assertNotEquals(quota, other)
    }
}
