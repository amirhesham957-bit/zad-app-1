package com.aistudio.zad.wrtqvx

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * ويدجت الشاشة الرئيسية: «متاح» وآخر ٣ معاملات — زي TransactionWidget بتاع كوتلن.
 * فوقهم سطر المناسبة (البادج والاسم على لونها، أو عدّاد «باقي ٣ أيام على …»)، وتحت الرقم
 * أول سطر في موجز النهارده.
 *
 * مابيعملش شبكة ولا حساب: التطبيق (home_widget_sync.dart) بيكتب القيم المنسّقة جاهزة
 * كل ما الميزانية أو المعاملات تتغير، والويدجت بيعرضها بس. الضغط عليه بيفتح التطبيق.
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

    private companion object {
        val ROWS = listOf(
            Triple(R.id.widget_tx_0, R.id.widget_tx_0_title, R.id.widget_tx_0_amount),
            Triple(R.id.widget_tx_1, R.id.widget_tx_1_title, R.id.widget_tx_1_amount),
            Triple(R.id.widget_tx_2, R.id.widget_tx_2_title, R.id.widget_tx_2_amount),
        )
    }
}
