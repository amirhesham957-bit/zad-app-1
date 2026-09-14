package com.example.ui.components

import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Insights
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.example.R
import com.example.data.CurrencyFormatter
import com.example.data.HabitsSummary
import com.example.ui.theme.*

/**
 * «عاداتك وتحركاتك» — اللي زاد اتعلمته من سلوكك، تحت كارت «إنت مين». الخروجات بتتحفظ من غير
 * إحداثيات، والعميل يقدر يمسحها كلها من هنا (RLS delete على zad_place_visits).
 */
@Composable
fun HabitsCard(summary: HabitsSummary, onClearOutings: () -> Unit, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .border(1.dp, outlineVariant, RoundedCornerShape(20.dp))
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Icon(Icons.Default.Insights, contentDescription = null, tint = primary, modifier = Modifier.size(22.dp))
            Column(Modifier.weight(1f)) {
                Text(stringResource(R.string.habits_title), style = Typography.titleSmall, fontWeight = FontWeight.Bold, color = onSurface)
                Text(stringResource(R.string.habits_subtitle), style = Typography.bodySmall, color = onSurfaceVariant)
            }
        }
        if (summary.isEmpty) {
            Text(stringResource(R.string.habits_empty), style = Typography.bodyMedium, color = onSurfaceVariant)
            return@Column
        }
        summary.avgWeeklySpending?.let { Line(stringResource(R.string.habits_weekly), CurrencyFormatter.format(context, it)) }
        if (summary.topCategories.isNotEmpty()) Line(stringResource(R.string.habits_top_categories), summary.topCategories.joinToString("، "))
        summary.busiestWeekday?.let { Line(stringResource(R.string.habits_busiest_day), it) }
        summary.subscriptionsMonthly?.let { Line(stringResource(R.string.habits_subscriptions), CurrencyFormatter.format(context, it)) }
        if (summary.outingsCount > 0) {
            Line(stringResource(R.string.habits_outings), stringResource(R.string.habits_outings_fmt, summary.outingsCount))
            summary.avgSpendPerOuting?.let { Line(stringResource(R.string.habits_per_outing), CurrencyFormatter.format(context, it)) }
            if (summary.topPlaces.isNotEmpty()) Line(stringResource(R.string.habits_places), summary.topPlaces.joinToString("، "))
            TextButton(onClick = onClearOutings, modifier = Modifier.heightIn(min = 44.dp)) {
                Text(stringResource(R.string.habits_clear_outings), color = dangerColor)
            }
        }
    }
}

@Composable
private fun Line(label: String, value: String) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(label, style = Typography.bodySmall, color = onSurfaceVariant, modifier = Modifier.width(130.dp))
        Text(value, style = Typography.bodyMedium, color = onSurface, modifier = Modifier.weight(1f))
    }
}
