package com.example.data

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/**
 * زينة كورة زاد اللي بتتفتح بدعوة العيلة (٢٠٢٦-٠٩-١٤) — «كل ما عيلتك تكبر في زاد، زاد تتزيّن».
 *
 * الفتح بعدد أفراد العيلة في التطبيق (العميل نفسه محسوب)، مش بعدد دعوات متتبّعة: مفيش جدول
 * دعوات، وأي فرد انضم فعلاً هو الدليل. الاختيار محفوظ على الجهاز بس — شكل شخصي مالوش لازمة
 * على السيرفر.
 */
enum class OrbAccessory(val prefValue: String, val familySizeNeeded: Int) {
    NONE("none", 1),
    BOW("bow", 2),
    GLASSES("glasses", 3),
    FLOWER("flower", 4),
    CROWN("crown", 5);

    fun isUnlocked(familySize: Int): Boolean = familySize >= familySizeNeeded

    companion object {
        fun from(value: String?): OrbAccessory = entries.firstOrNull { it.prefValue == value } ?: NONE

        /** الزينة اللي لسه مقفولة وأقرب واحدة للفتح — للجملة «فاضل فرد واحد وتفتح ...». */
        fun nextLocked(familySize: Int): OrbAccessory? = entries.firstOrNull { !it.isUnlocked(familySize) }
    }
}

/** الاختيار الحالي كحالة Compose — الكورة في أي شاشة بتقراه وتترسم تاني لما يتغير. */
object OrbAccessoryStore {
    private const val PREFS = "zad_orb"
    private const val KEY = "accessory"

    var current by mutableStateOf(OrbAccessory.NONE)
        private set

    fun load(context: Context) {
        current = OrbAccessory.from(context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null))
    }

    /** بيرفض زينة مقفولة — الاختيار مايعدّيش شرط الفتح حتى لو الواجهة غلطت. */
    fun select(context: Context, accessory: OrbAccessory, familySize: Int): Boolean {
        if (!accessory.isUnlocked(familySize)) return false
        current = accessory
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, accessory.prefValue).apply()
        return true
    }
}
