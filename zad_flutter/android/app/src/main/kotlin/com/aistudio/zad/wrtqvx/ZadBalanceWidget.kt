package com.aistudio.zad.wrtqvx

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import java.util.Calendar
import java.util.TimeZone
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * ويدجت الشاشة الرئيسية: «متاح» وآخر ٣ معاملات — زي TransactionWidget بتاع كوتلن.
 * فوقهم سطر المناسبة (البادج والاسم على لونها، أو عدّاد «باقي ٣ أيام على …»)، وتحت الرقم
 * أول سطر في موجز النهارده.
 *
 * مابيعملش شبكة ولا حساب: التطبيق (home_widget_sync.dart) بيكتب القيم المنسّقة جاهزة
 * كل ما الميزانية أو المعاملات تتغير، والويدجت بيعرضها بس. الضغط عليه بيفتح التطبيق.
 *
 * الاستثناء الوحيد سطر رفيق زاد: الجوع والعطش بيزيدوا والتطبيق مقفول، فالتطبيق بيكتب
 * لحظات «آخر مرة كان شبعان/مرتوي» والويدجت بيحسب الوش بنفسه كل ما يترسم (كل ٣٠ دقيقة).
 */
class ZadBalanceWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.zad_balance_widget).apply {
                setTextViewText(R.id.widget_balance, widgetData.getString("zad_available", "—"))
                setTextViewText(R.id.widget_updated, widgetData.getString("zad_updated", ""))
                val seasonLine = widgetData.getString("zad_season_line", null)
                if (seasonLine.isNullOrBlank()) {
                    setViewVisibility(R.id.widget_season, View.GONE)
                } else {
                    setViewVisibility(R.id.widget_season, View.VISIBLE)
                    setTextViewText(R.id.widget_season_badge, widgetData.getString("zad_season_badge", ""))
                    setTextViewText(R.id.widget_season_line, seasonLine)
                    // A colour the app wrote; a malformed one keeps the layout's green.
                    val color = runCatching {
                        Color.parseColor(widgetData.getString("zad_season_color", null))
                    }.getOrNull()
                    if (color != null) setInt(R.id.widget_season, "setBackgroundColor", color)
                }
                bindPet(this, widgetData)
                val brief = widgetData.getString("zad_brief", null)
                if (brief.isNullOrBlank()) {
                    setViewVisibility(R.id.widget_brief, View.GONE)
                } else {
                    setViewVisibility(R.id.widget_brief, View.VISIBLE)
                    setTextViewText(R.id.widget_brief, "📌 $brief")
                }
                var shown = 0
                for (i in 0 until 3) {
                    val title = widgetData.getString("zad_tx_${i}_title", null)
                    val amount = widgetData.getString("zad_tx_${i}_amount", null)
                    val row = ROWS[i]
                    if (title.isNullOrBlank() || amount.isNullOrBlank()) {
                        setViewVisibility(row.first, View.GONE)
                    } else {
                        shown++
                        setViewVisibility(row.first, View.VISIBLE)
                        setTextViewText(row.second, title)
                        setTextViewText(row.third, amount)
                    }
                }
                setViewVisibility(R.id.widget_empty, if (shown == 0) View.VISIBLE else View.GONE)
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    /** Mirrors `PetCare.mood` (pet_care.dart) — keep the two in step. */
    private fun bindPet(views: RemoteViews, data: SharedPreferences) {
        val name = data.getString("zad_pet_name", null)
        val fedAt = data.getString("zad_pet_fed_at", null)?.toLongOrNull()
        val wateredAt = data.getString("zad_pet_watered_at", null)?.toLongOrNull()
        if (name.isNullOrBlank() || fedAt == null || wateredAt == null) {
            views.setViewVisibility(R.id.widget_pet, View.GONE)
            return
        }
        fun span(key: String, fallback: Long) =
            data.getString(key, null)?.toLongOrNull()?.takeIf { it > 0 } ?: fallback
        val now = System.currentTimeMillis()
        fun level(full: Long?, span: Long) =
            if (full == null) 0.0 else (1.0 - (now - full).toDouble() / span).coerceIn(0.0, 1.0)
        val fullness = level(fedAt, span("zad_pet_hunger_ms", 20 * HOUR))
        val hydration = level(wateredAt, span("zad_pet_thirst_ms", 14 * HOUR))
        val joy = level(
            data.getString("zad_pet_petted_at", null)?.toLongOrNull(),
            span("zad_pet_joy_ms", 36 * HOUR),
        )
        val caredAt = data.getString("zad_pet_cared_at", null)?.toLongOrNull()
        val justCared = caredAt != null && now - caredAt < 15 * MINUTE
        val zone = data.getString("zad_pet_zone", null)
            ?.let { TimeZone.getTimeZone(it) } ?: TimeZone.getDefault()
        val hour = Calendar.getInstance(zone).apply { timeInMillis = now }
            .get(Calendar.HOUR_OF_DAY)
        val (face, line) = when {
            hour >= 23 || hour < 6 ->
                if (justCared) "😊" to "$name مبسوط 💚" else "😴" to "$name نايم… تصبح على خير"
            fullness < 0.15 && hydration < 0.15 -> "😢" to "$name زعلان… وحشته"
            hydration < NEED -> "🥵" to "$name عطشان — اسقيه 💧"
            fullness < NEED -> "🤤" to "$name جعان — أكّله 🍎"
            justCared || (fullness > 0.6 && hydration > 0.6 && joy > 0.3) ->
                "😊" to "$name مبسوط 💚"
            else -> "🙂" to "$name تمام"
        }
        views.setViewVisibility(R.id.widget_pet, View.VISIBLE)
        views.setTextViewText(R.id.widget_pet_face, face)
        views.setTextViewText(R.id.widget_pet_line, line)
        views.setTextViewText(
            R.id.widget_pet_levels,
            "🍎${(fullness * 100).toInt()}٪ 💧${(hydration * 100).toInt()}٪",
        )
    }

    private companion object {
        const val MINUTE = 60_000L
        const val HOUR = 60 * MINUTE
        const val NEED = 0.3

        val ROWS = listOf(
            Triple(R.id.widget_tx_0, R.id.widget_tx_0_title, R.id.widget_tx_0_amount),
            Triple(R.id.widget_tx_1, R.id.widget_tx_1_title, R.id.widget_tx_1_amount),
            Triple(R.id.widget_tx_2, R.id.widget_tx_2_title, R.id.widget_tx_2_amount),
        )
    }
}
