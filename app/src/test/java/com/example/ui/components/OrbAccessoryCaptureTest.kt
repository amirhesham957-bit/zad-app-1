package com.example.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.unit.dp
import com.example.data.OrbAccessory
import com.example.ui.theme.AppTheme
import com.example.ui.theme.background
import com.github.takahirom.roborazzi.captureRoboImage
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/** زينة الكورة كلها جنب بعض — لقطة للمراجعة بالعين (الرسم بالنسب لازم يبان صح). */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [33], qualifiers = "w720dp-h240dp-xhdpi")
class OrbAccessoryCaptureTest {
    @get:Rule
    val composeTestRule = createComposeRule()

    @Test
    fun allAccessories() {
        composeTestRule.setContent {
            AppTheme(darkTheme = false) {
                Row(Modifier.background(background).padding(16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    OrbAccessory.entries.forEach { CompanionOrb(state = CompanionState.Happy, size = 120.dp, animated = false, accessory = it) }
                }
            }
        }
        composeTestRule.onRoot().captureRoboImage("build/outputs/roborazzi/orb_accessories.png")
    }
}
