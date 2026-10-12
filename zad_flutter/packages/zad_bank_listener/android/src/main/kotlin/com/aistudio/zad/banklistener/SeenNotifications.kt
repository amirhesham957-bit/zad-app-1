package com.aistudio.zad.banklistener

/**
 * ذاكرة «الإشعار ده اتلقط قبل كده» — عشان إعادة ربط الخدمة ماتبعتش نفس الرسالة تاني.
 *
 * من غير أي حاجة من أندرويد عن قصد: الخدمة نفسها مابتشتغلش على الديسك، فالقرار هنا
 * بيتختبر على JVM (`SeenNotificationsTest`) والخدمة بتنادي عليه بس.
 *
 * **الهوية = المفتاح + وقت النشر، مش المفتاح لوحده.** تطبيق الرسايل بيحدّث إشعار
 * المحادثة نفسه (نفس المفتاح) لما رسالة بنك جديدة توصل. بالمفتاح لوحده، رسالة وصلت
 * والخدمة مفكوكة كانت بتتشاف «اتلقطت قبل كده» وتضيع — وده بالظبط اللي المسح عند
 * الربط موجود عشانه. وقت النشر بيتغيّر مع كل تحديث، فالرسالة الجديدة بتتلقط والقديمة لأ.
 */
internal object SeenNotifications {
    /** أقصى عدد بنفتكره — أكتر من أي شريط إشعارات حقيقي. */
    const val MAX = 300

    /** هوية إشعار واحد بنسخته الحالية. */
    fun id(key: String, postTime: Long): String = "$key|$postTime"

    /** اللي المسح يلقطه، واللي يتحفظ بعده. */
    data class Scan(val toCapture: List<String>, val remember: Set<String>)

    /**
     * المسح عند الربط: يلقط بس اللي مااتشافش.
     *
     * اللي بيتحفظ بعده هو الشريط الحالي بس: إشعار مش ظاهر دلوقتي مش هيرجع بنفس
     * الهوية من غير ما يعدّي على `onNotificationPosted`، اللي بيفتكره هو كمان.
     */
    fun scan(seen: Set<String>, active: List<String>, max: Int = MAX): Scan =
        Scan(
            toCapture = active.filter { it !in seen }.distinct(),
            remember = newest(active.toSet(), max),
        )

    /** إشعار اتلقط وهي مربوطة: يتفتكر عشان المسح الجاي مايلقطهوش تاني. */
    fun remember(seen: Set<String>, id: String, max: Int = MAX): Set<String> =
        newest(seen + id, max)

    /** فوق السقف بيتشال الأقدم بوقت النشر — مش ترتيب عشوائي من `HashSet`. */
    private fun newest(ids: Set<String>, max: Int): Set<String> =
        if (ids.size <= max) ids
        else ids.sortedByDescending(::postTimeOf).take(max).toSet()

    /**
     * هوية قديمة (مفتاح من غير وقت، من نسخة سابقة) بتتحسب الأقدم: آخر مفتاح أندرويد
     * هو الـ uid، رقم صغير جنب أي وقت نشر حقيقي بالملّي ثانية.
     */
    private fun postTimeOf(id: String): Long =
        id.substringAfterLast('|', "").toLongOrNull() ?: 0L
}
