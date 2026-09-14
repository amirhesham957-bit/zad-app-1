package com.example.voice

import android.media.AudioManager
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * قرار المستخدم: زاد "تتكلم لوحدها" — بس مش في اجتماع ولا والموبايل في الجيب. التست بيقفل
 * الشروط التلاتة: الشاشة مفتوحة، الموبايل مش صامت/هزاز، والتنبيهات الصوتية مش مقفولة.
 */
class VoiceMomentSpeakerTest {
    @Test
    fun speaksOnlyWhenScreenIsOnRingerIsNormalAndSettingIsOn() {
        assertTrue(VoiceMomentSpeaker.shouldAutoSpeak(true, AudioManager.RINGER_MODE_NORMAL, true))
        assertFalse(VoiceMomentSpeaker.shouldAutoSpeak(false, AudioManager.RINGER_MODE_NORMAL, true))
        assertFalse(VoiceMomentSpeaker.shouldAutoSpeak(true, AudioManager.RINGER_MODE_VIBRATE, true))
        assertFalse(VoiceMomentSpeaker.shouldAutoSpeak(true, AudioManager.RINGER_MODE_SILENT, true))
        assertFalse(VoiceMomentSpeaker.shouldAutoSpeak(true, AudioManager.RINGER_MODE_NORMAL, false))
    }
}
