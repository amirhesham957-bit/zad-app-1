package com.example.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Savings
import androidx.compose.material.icons.filled.Shield
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
import com.example.data.ZadBrokeMode
import com.example.ui.theme.*

/**
 * بانر وضع الطوارئ في الرئيسية: مصروف اليوم والأيام الباقية، وزرار الخروج. من غير رقم
 * (مانعرفش معاه كام) بيطلب المبلغ بدل ما يعرض صفر كأنه حساب.
 */
@Composable
fun BrokeModeBanner(
    mode: ZadBrokeMode,
    daysLeft: Int,
    onSetCash: () -> Unit,
    onExit: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(errorContainer)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Box(
                modifier = Modifier.size(40.dp).clip(CircleShape).background(onErrorContainer.copy(alpha = 0.12f)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Default.Shield, contentDescription = null, tint = onErrorContainer, modifier = Modifier.size(22.dp))
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(stringResource(R.string.broke_mode_title), style = Typography.titleSmall, fontWeight = FontWeight.Bold, color = onErrorContainer)
                Text(
                    mode.dailyCap?.let { stringResource(R.string.broke_mode_daily_cap, CurrencyFormatter.format(context, it), daysLeft.coerceAtLeast(1)) }
                        ?: stringResource(R.string.broke_mode_no_cash),
                    style = Typography.bodyMedium,
                    color = onErrorContainer,
                )
            }
        }
        Text(stringResource(R.string.broke_mode_effects), style = Typography.bodySmall, color = onErrorContainer.copy(alpha = 0.85f))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            if (mode.dailyCap == null) {
                Button(onClick = onSetCash, modifier = Modifier.heightIn(min = 44.dp)) { Text(stringResource(R.string.broke_mode_set_cash)) }
            }
            TextButton(onClick = onExit, modifier = Modifier.heightIn(min = 44.dp)) {
                Text(stringResource(R.string.broke_mode_exit), color = onErrorContainer, fontWeight = FontWeight.SemiBold)
            }
        }
    }
}

/** مدخل يدوي في شاشة الميزانية — لمن مش هيقولها بصوته. */
@Composable
fun BrokeModeEntryCard(onActivate: () -> Unit, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .border(1.dp, outlineVariant, RoundedCornerShape(16.dp))
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(Icons.Default.Savings, contentDescription = null, tint = dangerColor, modifier = Modifier.size(24.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(stringResource(R.string.broke_mode_entry_title), style = Typography.bodyLarge, fontWeight = FontWeight.SemiBold, color = onSurface)
            Text(stringResource(R.string.broke_mode_entry_sub), style = Typography.bodySmall, color = onSurfaceVariant)
        }
        OutlinedButton(onClick = onActivate, modifier = Modifier.heightIn(min = 44.dp)) { Text(stringResource(R.string.broke_mode_activate)) }
    }
}

/** «معاك كام لآخر الشهر؟» — فاضي = يستخدم الرصيد المتأكد لو موجود. */
@Composable
fun BrokeModeDialog(
    daysLeft: Int,
    onDismiss: () -> Unit,
    onConfirm: (cashLeft: Double?) -> Unit,
) {
    var cash by remember { mutableStateOf("") }
    val parsed = cash.trim().replace(',', '.').toDoubleOrNull()
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = surface,
        title = { Text(stringResource(R.string.broke_mode_dialog_title), style = Typography.titleLarge, fontWeight = FontWeight.Bold) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(stringResource(R.string.broke_mode_dialog_body, daysLeft.coerceAtLeast(1)), style = Typography.bodyMedium, color = onSurfaceVariant)
                OutlinedTextField(
                    value = cash,
                    onValueChange = { v -> cash = v.filter { it.isDigit() || it == '.' || it == ',' }.take(12) },
                    label = { Text(stringResource(R.string.broke_mode_cash_label)) },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    colors = OutlinedTextFieldDefaults.colors(
                        unfocusedBorderColor = onSurfaceVariant.copy(alpha = 0.72f),
                        focusedBorderColor = primary,
                    ),
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        },
        confirmButton = {
            Button(enabled = cash.isBlank() || parsed != null, onClick = { onConfirm(parsed) }) {
                Text(stringResource(R.string.broke_mode_activate))
            }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) } },
    )
}
