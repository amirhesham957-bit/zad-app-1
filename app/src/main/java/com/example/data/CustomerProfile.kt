package com.example.data

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * ملف العميل عند زاد (`zad_customer_profile`، ميجريشن 20260914012000) — «إنت مين»: الاسم،
 * النوع، دوره في البيت، شغله، ميعاد قبضه... العقل بيملاه من الكلام (update_customer_profile)،
 * والعميل بيشوفه ويعدّله من «زاد عارف عني إيه». القيم المقفولة (النوع/الدور/اللهجة) بيانات
 * مطابقة زي قيد الجدول — مش نصوص عرض.
 */
@Serializable
data class ZadCustomerProfile(
    @SerialName("preferred_name") val preferredName: String? = null,
    val gender: String? = null,
    @SerialName("household_role") val householdRole: String? = null,
    @SerialName("age_range") val ageRange: String? = null,
    val occupation: String? = null,
    @SerialName("work_schedule") val workSchedule: String? = null,
    @SerialName("pay_day") val payDay: Int? = null,
    @SerialName("pay_frequency") val payFrequency: String? = null,
    @SerialName("income_source") val incomeSource: String? = null,
    @SerialName("household_size") val householdSize: Int? = null,
    @SerialName("kids_count") val kidsCount: Int? = null,
    val city: String? = null,
    val dialect: String? = null,
    val interests: List<String>? = null,
    val notes: String? = null,
)

object CustomerProfileOptions {
    val GENDERS = listOf("male", "female")
    val ROLES = listOf("father", "mother", "husband", "wife", "son", "daughter", "single", "student", "grandparent", "other")
    val PAY_FREQUENCIES = listOf("monthly", "biweekly", "weekly", "daily", "irregular")
    val DIALECTS = listOf("EG", "SA", "GULF", "LEVANT", "IQ", "MA", "TN", "DZ", "LY", "SD", "YE", "TR", "EN")

    /** بيقص ويتأكد من القيم قبل الإرسال — نفس حدود قيد الجدول، عشان الحفظ مايترفضش. */
    fun normalized(p: ZadCustomerProfile): ZadCustomerProfile = p.copy(
        preferredName = p.preferredName?.trim()?.take(40)?.ifBlank { null },
        gender = p.gender?.takeIf { it in GENDERS },
        householdRole = p.householdRole?.takeIf { it in ROLES },
        occupation = p.occupation?.trim()?.take(80)?.ifBlank { null },
        workSchedule = p.workSchedule?.trim()?.take(120)?.ifBlank { null },
        payDay = p.payDay?.takeIf { it in 1..31 },
        payFrequency = p.payFrequency?.takeIf { it in PAY_FREQUENCIES },
        incomeSource = p.incomeSource?.trim()?.take(80)?.ifBlank { null },
        householdSize = p.householdSize?.takeIf { it in 1..30 },
        kidsCount = p.kidsCount?.takeIf { it in 0..20 },
        city = p.city?.trim()?.take(60)?.ifBlank { null },
        dialect = p.dialect?.takeIf { it in DIALECTS },
        notes = p.notes?.trim()?.take(500)?.ifBlank { null },
    )
}
