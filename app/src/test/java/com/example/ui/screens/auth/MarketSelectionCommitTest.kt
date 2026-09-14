package com.example.ui.screens.auth

import android.app.Application
import androidx.test.core.app.ApplicationProvider
import com.example.data.Market
import com.example.data.MarketPrefs
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * بلاغ ٢٠٢٦-٠٩-١٤: "اختيار البلد بيتكرر مرتين". الحفظ كان في coroutine والنقل بعده على
 * طول، فشاشة السبلاش كانت بتلاقي مفيش بلد وتفتح الاختيار تاني. التست بيقفل الترتيب:
 * لحظة ما الدالة ترجع (قبل أي مزامنة) البلد لازم يكون محفوظ.
 */
@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE)
class MarketSelectionCommitTest {

    private val context get() = ApplicationProvider.getApplicationContext<Application>()

    @Before
    fun clear() {
        context.getSharedPreferences("zad_market_prefs", android.content.Context.MODE_PRIVATE).edit().clear().commit()
    }

    @Test
    fun marketIsSavedBeforeTheScreenNavigatesAndBeforeAnySync() {
        var syncStarted = false
        var savedWhenSyncWasLaunched: Boolean? = null
        commitMarketSelection(context, Market.EGYPT) { _ ->
            savedWhenSyncWasLaunched = MarketPrefs.hasSelectedMarket(context)
            syncStarted = true // عمدًا مابنشغّلش البلوك: مفيش شبكة في التست
        }
        assertTrue("البلد لازم يتحفظ فورًا — navigateAfterSplash بيقراه بعدها على طول", MarketPrefs.hasSelectedMarket(context))
        assertEquals(true, savedWhenSyncWasLaunched)
        assertTrue(syncStarted)
    }

    @Test
    fun nothingIsSavedUntilTheUserConfirms() {
        assertFalse(MarketPrefs.hasSelectedMarket(context))
    }
}
