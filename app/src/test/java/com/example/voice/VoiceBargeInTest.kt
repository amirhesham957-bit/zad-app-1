package com.example.voice

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * المقاطعة كانت مستحيلة بالتصميم: المايك كان بيتكتم طول ما زاد بيتكلم. دلوقتي بيفضل
 * مفتوح، والبوابة دي بتفرّق بين كلام المستخدم وصدى صوت زاد نفسه.
 */
class VoiceBargeInTest {

    private fun pcmOf(amplitude: Int, samples: Int = 1600): ByteArray {
        val out = ByteArray(samples * 2)
        for (i in 0 until samples) {
            val v = if (i % 2 == 0) amplitude else -amplitude
            out[i * 2] = (v and 0xFF).toByte()
            out[i * 2 + 1] = ((v shr 8) and 0xFF).toByte()
        }
        return out
    }

    @Test
    fun everythingIsForwardedWhileZadIsSilent() {
        assertTrue(shouldForwardMic(modelSpeaking = false, level = 0f))
        assertTrue(shouldForwardMic(modelSpeaking = false, level = 0.05f))
    }

    @Test
    fun onlyClearSpeechInterruptsWhileZadSpeaks() {
        assertFalse("صدى واطي مايقاطعش", shouldForwardMic(modelSpeaking = true, level = BARGE_IN_LEVEL - 0.01f))
        assertTrue("كلام واضح بيقاطع", shouldForwardMic(modelSpeaking = true, level = BARGE_IN_LEVEL))
    }

    @Test
    fun pcmLevelTracksLoudness() {
        assertEquals(0f, pcmLevel(pcmOf(0)), 0.0001f)
        val quietEcho = pcmLevel(pcmOf(600))      // ≈ -35 dBFS
        val nearSpeech = pcmLevel(pcmOf(4000))    // ≈ -18 dBFS
        assertTrue(quietEcho < BARGE_IN_LEVEL)
        assertTrue(nearSpeech >= BARGE_IN_LEVEL)
        assertEquals(1f, pcmLevel(pcmOf(Short.MAX_VALUE.toInt())), 0.0001f)
        assertEquals(0f, pcmLevel(ByteArray(1)), 0.0001f)
    }
}
