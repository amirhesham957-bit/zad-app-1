package com.example.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.example.R
import com.example.data.WeekSummary
import com.example.ui.theme.*

/**
 * «أسبوعك مع زاد» في الرئيسية: سطر التغيير عن الأسبوع اللي فات، أكتر فئة، وزرار يعمل صورة
 * تتشير (WeeklyShareCard). اللوحة غامقة ثابتة في الثيمين زي ZadDarkPanel، والألوان فوقها من
 * توكنات اللوحة المقاسة (WcagContrastTest).
 */
@Composable
fun WeekWithZadCard(week: WeekSummary, onShare: () -> Unit, modifier: Modifier = Modifier) {
    val pct = week.changePct
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(ZadDarkPanelBackground)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                stringResource(R.string.week_share_title),
                style = Typography.labelLarge,
                fontWeight = FontWeight.Bold,
                color = ZadDarkPanelAccent,
                modifier = Modifier.weight(1f),
            )
            FilledTonalButton(onClick = onShare, modifier = Modifier.heightIn(min = 44.dp)) {
                Icon(Icons.Default.Share, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(8.dp))
                Text(stringResource(R.string.week_share_action))
            }
        }
        Text(
            when {
                pct == null -> stringResource(R.string.week_share_first_week)
                pct < 0 -> stringResource(R.string.week_share_less, -pct)
                pct > 0 -> stringResource(R.string.week_share_more, pct)
                else -> stringResource(R.string.week_share_same)
            },
            style = Typography.titleLarge,
            fontWeight = FontWeight.ExtraBold,
            color = if (pct != null && pct > 0) ZadDarkPanelWarning else androidx.compose.ui.graphics.Color.White,
        )
        week.topCategory?.let {
            Text(stringResource(R.string.week_share_top_category, it), style = Typography.bodyMedium, color = androidx.compose.ui.graphics.Color.White.copy(alpha = 0.8f))
        }
    }
}
