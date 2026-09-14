package com.example.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.example.R
import com.example.data.CurrencyFormatter
import com.example.data.ZadSavingsChallenge
import com.example.ui.theme.*

/**
 * كارت التحدي الشغال: اليوم كام من كام، السلسلة، وصرف النهارده قدام السقف (حي من المعاملات).
 * السلسلة والأيام من تقييم السيرفر؛ شريط النهارده بس هو اللي بيتحسب هنا.
 */
@Composable
fun SavingsChallengeCard(
    challenge: ZadSavingsChallenge,
    dayIndex: Int,
    todaySpent: Double,
    onShare: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val ratio = if (challenge.dailyCap > 0) (todaySpent / challenge.dailyCap).toFloat() else 1f
    val animated by animateFloatAsState(ratio.coerceIn(0f, 1f), ZadSprings.Screen, label = "challengeToday")
    val over = todaySpent > challenge.dailyCap
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(surface)
            .border(1.dp, outlineVariant, RoundedCornerShape(20.dp))
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Icon(Icons.Default.EmojiEvents, contentDescription = null, tint = warningColor, modifier = Modifier.size(22.dp))
            Column(Modifier.weight(1f)) {
                Text(stringResource(R.string.challenge_title, challenge.lengthDays), style = Typography.titleSmall, fontWeight = FontWeight.Bold, color = onSurface)
                Text(stringResource(R.string.challenge_day_of, dayIndex, challenge.lengthDays), style = Typography.bodySmall, color = onSurfaceVariant)
            }
            IconButton(onClick = onShare) {
                Icon(Icons.Default.Share, contentDescription = stringResource(R.string.challenge_share_cd), tint = primary)
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            ChallengeStat(value = "🔥 ${challenge.streak}", label = stringResource(R.string.challenge_streak))
            ChallengeStat(value = "${challenge.daysWon}", label = stringResource(R.string.challenge_days_won))
            ChallengeStat(value = "${challenge.bestStreak}", label = stringResource(R.string.challenge_best))
        }
        Text(
            stringResource(
                R.string.challenge_today,
                CurrencyFormatter.format(context, todaySpent),
                CurrencyFormatter.format(context, challenge.dailyCap),
            ),
            style = Typography.bodyMedium,
            color = if (over) dangerColor else onSurface,
        )
        LinearProgressIndicator(
            progress = { animated },
            color = if (over) dangerColor else primary,
            trackColor = outlineVariant,
            modifier = Modifier.fillMaxWidth().height(8.dp).clip(RoundedCornerShape(4.dp)),
        )
    }
}

@Composable
private fun ChallengeStat(value: String, label: String) {
    Column {
        Text(value, style = Typography.titleMedium, fontWeight = FontWeight.Bold, color = onSurface)
        Text(label, style = Typography.labelSmall, color = onSurfaceVariant)
    }
}

@Composable
fun SavingsChallengeEntryCard(onStart: () -> Unit, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .border(1.dp, outlineVariant, RoundedCornerShape(16.dp))
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(Icons.Default.EmojiEvents, contentDescription = null, tint = warningColor, modifier = Modifier.size(24.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(stringResource(R.string.challenge_entry_title), style = Typography.bodyLarge, fontWeight = FontWeight.SemiBold, color = onSurface)
            Text(stringResource(R.string.challenge_entry_sub), style = Typography.bodySmall, color = onSurfaceVariant)
        }
        OutlinedButton(onClick = onStart, modifier = Modifier.heightIn(min = 44.dp)) { Text(stringResource(R.string.challenge_start)) }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun SavingsChallengeDialog(
    suggestedCap: Double?,
    onDismiss: () -> Unit,
    onStart: (dailyCap: Double, lengthDays: Int) -> Unit,
) {
    var cap by remember { mutableStateOf(suggestedCap?.let { it.toLong().toString() } ?: "") }
    var length by remember { mutableIntStateOf(30) }
    val parsed = cap.trim().replace(',', '.').toDoubleOrNull()?.takeIf { it >= 1 }
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = surface,
        title = { Text(stringResource(R.string.challenge_entry_title), style = Typography.titleLarge, fontWeight = FontWeight.Bold) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(
                    if (suggestedCap != null) stringResource(R.string.challenge_dialog_suggested) else stringResource(R.string.challenge_dialog_no_suggestion),
                    style = Typography.bodyMedium,
                    color = onSurfaceVariant,
                )
                OutlinedTextField(
                    value = cap,
                    onValueChange = { v -> cap = v.filter { it.isDigit() || it == '.' || it == ',' }.take(10) },
                    label = { Text(stringResource(R.string.challenge_cap_label)) },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    colors = OutlinedTextFieldDefaults.colors(
                        unfocusedBorderColor = onSurfaceVariant.copy(alpha = 0.72f),
                        focusedBorderColor = primary,
                    ),
                    modifier = Modifier.fillMaxWidth(),
                )
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf(7, 14, 30).forEach { d ->
                        FilterChip(
                            selected = length == d,
                            onClick = { length = d },
                            label = { Text(stringResource(R.string.challenge_length_fmt, d), style = Typography.labelLarge) },
                        )
                    }
                }
            }
        },
        confirmButton = {
            Button(enabled = parsed != null, onClick = { parsed?.let { onStart(it, length) } }) { Text(stringResource(R.string.challenge_start)) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) } },
    )
}
