package com.example.data

/**
 * هل الصنف ده ينفع يدخل في وصفة؟ مولّد شيف زاد الاحتياطي كان بياخد أول ٣ أصناف في المخزون
 * أياً كانت، فطلع على جهاز حقيقي كارت "وجبة منزلية سريعة بـ ماء إيلان" (٢٠٢٦-٠٩-١٤).
 * مخزون الإنتاج وقتها كان فيه ٦ أصناف مياه ("إزازة ماء"، "كرتونة ماية"، "عبوة مياه"...)
 * و"علبة حفظ طعام" تحت "أخرى".
 *
 * ⚠️ الكلمات دي **بيانات مطابقة** مش نصوص عرض (قاعدة i18n في CLAUDE.md): بتتطابق مع
 * `ZadInventory.category`/`itemName` زي ما المستخدم أو الكاميرا كتبوها — ممنوع تتترجم.
 * التصنيفات بصيغتين لأن الإنتاج فيه الاتنين ("مشروبات" و"المشروبات").
 */
internal fun isCookableIngredient(itemName: String, category: String?): Boolean {
    val cat = category?.trim().orEmpty()
    if (NON_FOOD_CATEGORY_MARKERS.any { cat.contains(it) }) return false
    val name = itemName.trim().lowercase()
    if (name.isEmpty()) return false
    return NON_COOKABLE_NAME_MARKERS.none { name.contains(it) }
}

private val NON_FOOD_CATEGORY_MARKERS = listOf(
    "مشروب", "منظف", "رعاية", "عناية", "أخرى", "اخرى", "وجبات خفيفة", "سناكس",
)

private val NON_COOKABLE_NAME_MARKERS = listOf(
    // مياه بكل الإملاءات اللي ظهرت فعلاً
    "ماء", "مياه", "مياة", "ماية", "water",
    // مشروبات جاهزة
    "عصير", "بيبسي", "كولا", "سفن اب", "مشروب", "juice", "cola", "soda",
    // مش أكل أصلاً
    "علبة حفظ", "مناديل", "صابون", "شامبو", "منظف", "كلور", "فويل",
    // سناكس جاهزة
    "برينجلز", "pringles", "شيبسي", "chips",
)
