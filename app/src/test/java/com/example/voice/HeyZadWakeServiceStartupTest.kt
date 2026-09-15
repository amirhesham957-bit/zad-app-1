package com.example.voice

import android.Manifest
import android.app.Application
import android.app.Service
import android.content.Intent
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

/**
 * كراش الإقلاع على أندرويد ١٤+ (بيلد 940e1554): `WakePrefs` مفعّلة افتراضيًا، فالخدمة كانت
 * بتتشغل من أول فتحة قبل أي طلب لـ RECORD_AUDIO، و`startForeground(type=MICROPHONE)` من
 * غير الإذن بيرمي SecurityException من جوه onCreate الخدمة — بره أي try/catch.
 *
 * Robolectric مابيطبّقش شرط الإذن ده بنفسه (و`startForeground` final)، فالتست مابيعيدش إنتاج
 * الرمية — بيقفل الحارس اللي بيمنع الوصول ليها: من غير الإذن مفيش startForegroundService،
 * والخدمة لو اتعملت من طريق تاني (pause/resume بيعملوها بـ startService) مابتروحش foreground
 * وبتقفل نفسها ومابترجعش sticky.
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34])
class HeyZadWakeServiceStartupTest {

    private val app: Application get() = ApplicationProvider.getApplicationContext()

    @Test
    fun start_withoutMicPermission_startsNothing() {
        shadowOf(app).denyPermissions(Manifest.permission.RECORD_AUDIO)

        HeyZadWakeService.start(app)

        assertNull(shadowOf(app).nextStartedService)
    }

    @Test
    fun start_withMicPermission_startsTheService() {
        shadowOf(app).grantPermissions(Manifest.permission.RECORD_AUDIO)

        HeyZadWakeService.start(app)

        assertEquals(
            HeyZadWakeService::class.java.name,
            shadowOf(app).nextStartedService?.component?.className,
        )
    }

    @Test
    fun serviceCreatedWithoutMicPermission_neverGoesForeground_andDoesNotStick() {
        shadowOf(app).denyPermissions(Manifest.permission.RECORD_AUDIO)

        val service = Robolectric.buildService(HeyZadWakeService::class.java).create().get()

        assertNull(shadowOf(service).lastForegroundNotification)
        assertTrue(shadowOf(service).isStoppedBySelf)
        assertEquals(Service.START_NOT_STICKY, service.onStartCommand(Intent(), 0, 1))
    }

    @Test
    fun serviceCreatedWithMicPermission_goesForeground() {
        shadowOf(app).grantPermissions(Manifest.permission.RECORD_AUDIO)

        val service = Robolectric.buildService(HeyZadWakeService::class.java).create().get()

        assertTrue(shadowOf(service).lastForegroundNotification != null)
    }
}
