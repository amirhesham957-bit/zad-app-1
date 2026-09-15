package com.example.ui.components

import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Badge
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.example.R
import com.example.data.CustomerProfileOptions
import com.example.data.ZadCustomerProfile
import com.example.ui.theme.*

/**
 * «إنت مين عند زاد» — أول كارت في شاشة الذاكرة. بيعرض اللي زاد عارفه (أو «لسه مش عارفة») وزرار
 * تعديل. شفافية: العميل يشوف بالظبط اللي بيتقال للعقل عنه ويصلّحه.
 */
@Composable
fun CustomerProfileCard(profile: ZadCustomerProfile?, onEdit: () -> Unit, modifier: Modifier = Modifier) {
    val p = profile ?: ZadCustomerProfile()
    val unknown = stringResource(R.string.profile_unknown)
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .border(1.dp, outlineVariant, RoundedCornerShape(20.dp))
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Icon(Icons.Default.Badge, contentDescription = null, tint = primary, modifier = Modifier.size(22.dp))
            Column(Modifier.weight(1f)) {
                Text(stringResource(R.string.profile_card_title), style = Typography.titleSmall, fontWeight = FontWeight.Bold, color = onSurface)
                Text(stringResource(R.string.profile_card_subtitle), style = Typography.bodySmall, color = onSurfaceVariant)
            }
            FilledTonalButton(onClick = onEdit, modifier = Modifier.heightIn(min = 44.dp)) {
                Icon(Icons.Default.Edit, contentDescription = null, modifier = Modifier.size(16.dp))
                Spacer(Modifier.width(6.dp))
                Text(stringResource(R.string.profile_edit))
            }
        }
        ProfileLine(stringResource(R.string.profile_name), p.preferredName ?: unknown)
        ProfileLine(stringResource(R.string.profile_gender), p.gender?.let { stringResource(genderLabel(it)) } ?: unknown)
        ProfileLine(stringResource(R.string.profile_role), p.householdRole?.let { stringResource(roleLabel(it)) } ?: unknown)
        ProfileLine(stringResource(R.string.profile_age), p.ageRange?.let { stringResource(ageLabel(it)) } ?: unknown)
        ProfileLine(stringResource(R.string.profile_occupation), p.occupation ?: unknown)
        ProfileLine(
            stringResource(R.string.profile_pay),
            p.payDay?.let { stringResource(R.string.profile_pay_day_fmt, it) + (p.payFrequency?.let { f -> " · " + stringResource(freqLabel(f)) } ?: "") } ?: unknown,
        )
        ProfileLine(stringResource(R.string.profile_household), listOfNotNull(
            p.householdSize?.let { stringResource(R.string.profile_household_size_fmt, it) },
            p.kidsCount?.let { stringResource(R.string.profile_kids_fmt, it) },
        ).joinToString(" · ").ifBlank { unknown })
        ProfileLine(stringResource(R.string.profile_city), p.city ?: unknown)
        ProfileLine(stringResource(R.string.profile_dialect), p.dialect?.let { stringResource(dialectLabel(it)) } ?: stringResource(R.string.profile_dialect_auto))
    }
}

@Composable
private fun ProfileLine(label: String, value: String) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(label, style = Typography.bodySmall, color = onSurfaceVariant, modifier = Modifier.width(110.dp))
        Text(value, style = Typography.bodyMedium, color = onSurface, modifier = Modifier.weight(1f))
    }
}

fun genderLabel(v: String): Int = if (v == "female") R.string.profile_gender_female else R.string.profile_gender_male

fun roleLabel(v: String): Int = when (v) {
    "father" -> R.string.profile_role_father
    "mother" -> R.string.profile_role_mother
    "husband" -> R.string.profile_role_husband
    "wife" -> R.string.profile_role_wife
    "son" -> R.string.profile_role_son
    "daughter" -> R.string.profile_role_daughter
    "single" -> R.string.profile_role_single
    "student" -> R.string.profile_role_student
    "grandparent" -> R.string.profile_role_grandparent
    else -> R.string.profile_role_other
}

fun ageLabel(v: String): Int = when (v) {
    "under_18" -> R.string.profile_age_under_18
    "18_24" -> R.string.profile_age_18_24
    "25_34" -> R.string.profile_age_25_34
    "35_44" -> R.string.profile_age_35_44
    "45_54" -> R.string.profile_age_45_54
    else -> R.string.profile_age_55_plus
}

fun freqLabel(v: String): Int = when (v) {
    "weekly" -> R.string.profile_freq_weekly
    "biweekly" -> R.string.profile_freq_biweekly
    "daily" -> R.string.profile_freq_daily
    "irregular" -> R.string.profile_freq_irregular
    else -> R.string.profile_freq_monthly
}

fun dialectLabel(v: String): Int = when (v) {
    "SA" -> R.string.profile_dialect_sa
    "GULF" -> R.string.profile_dialect_gulf
    "LEVANT" -> R.string.profile_dialect_levant
    "IQ" -> R.string.profile_dialect_iq
    "MA" -> R.string.profile_dialect_ma
    "TN" -> R.string.profile_dialect_tn
    "DZ" -> R.string.profile_dialect_dz
    "LY" -> R.string.profile_dialect_ly
    "SD" -> R.string.profile_dialect_sd
    "YE" -> R.string.profile_dialect_ye
    "TR" -> R.string.profile_dialect_tr
    "EN" -> R.string.profile_dialect_en
    else -> R.string.profile_dialect_eg
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun CustomerProfileDialog(
    initial: ZadCustomerProfile?,
    saving: Boolean,
    onDismiss: () -> Unit,
    onSave: (ZadCustomerProfile) -> Unit,
) {
    val start = initial ?: ZadCustomerProfile()
    var name by remember { mutableStateOf(start.preferredName.orEmpty()) }
    var gender by remember { mutableStateOf(start.gender) }
    var role by remember { mutableStateOf(start.householdRole) }
    var age by remember { mutableStateOf(start.ageRange) }
    var occupation by remember { mutableStateOf(start.occupation.orEmpty()) }
    var payDay by remember { mutableStateOf(start.payDay?.toString().orEmpty()) }
    var freq by remember { mutableStateOf(start.payFrequency) }
    var household by remember { mutableStateOf(start.householdSize?.toString().orEmpty()) }
    var kids by remember { mutableStateOf(start.kidsCount?.toString().orEmpty()) }
    var city by remember { mutableStateOf(start.city.orEmpty()) }
    var dialect by remember { mutableStateOf(start.dialect) }
    val fieldColors = OutlinedTextFieldDefaults.colors(unfocusedBorderColor = onSurfaceVariant.copy(alpha = 0.72f), focusedBorderColor = primary)

    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = surface,
        title = { Text(stringResource(R.string.profile_card_title), style = Typography.titleLarge, fontWeight = FontWeight.Bold) },
        text = {
            Column(Modifier.heightIn(max = 520.dp).verticalScroll(rememberScrollState()).imePadding(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedTextField(name, { name = it.take(40) }, label = { Text(stringResource(R.string.profile_name)) }, singleLine = true, colors = fieldColors, modifier = Modifier.fillMaxWidth())
                ChipGroup(stringResource(R.string.profile_gender), CustomerProfileOptions.GENDERS, gender, { gender = it }) { stringResource(genderLabel(it)) }
                ChipGroup(stringResource(R.string.profile_role), CustomerProfileOptions.ROLES, role, { role = it }) { stringResource(roleLabel(it)) }
                ChipGroup(stringResource(R.string.profile_age), CustomerProfileOptions.AGE_RANGES, age, { age = it }) { stringResource(ageLabel(it)) }
                OutlinedTextField(occupation, { occupation = it.take(80) }, label = { Text(stringResource(R.string.profile_occupation)) }, singleLine = true, colors = fieldColors, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(payDay, { payDay = it.filter(Char::isDigit).take(2) }, label = { Text(stringResource(R.string.profile_pay_day_label)) }, singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), colors = fieldColors, modifier = Modifier.fillMaxWidth())
                ChipGroup(stringResource(R.string.profile_pay_frequency), CustomerProfileOptions.PAY_FREQUENCIES, freq, { freq = it }) { stringResource(freqLabel(it)) }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(household, { household = it.filter(Char::isDigit).take(2) }, label = { Text(stringResource(R.string.profile_household_size)) }, singleLine = true,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), colors = fieldColors, modifier = Modifier.weight(1f))
                    OutlinedTextField(kids, { kids = it.filter(Char::isDigit).take(2) }, label = { Text(stringResource(R.string.profile_kids)) }, singleLine = true,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), colors = fieldColors, modifier = Modifier.weight(1f))
                }
                OutlinedTextField(city, { city = it.take(60) }, label = { Text(stringResource(R.string.profile_city)) }, singleLine = true, colors = fieldColors, modifier = Modifier.fillMaxWidth())
                ChipGroup(stringResource(R.string.profile_dialect), CustomerProfileOptions.DIALECTS, dialect, { dialect = it }) { stringResource(dialectLabel(it)) }
            }
        },
        confirmButton = {
            Button(enabled = !saving, onClick = {
                onSave(
                    CustomerProfileOptions.normalized(
                        start.copy(
                            preferredName = name, gender = gender, householdRole = role, ageRange = age, occupation = occupation,
                            payDay = payDay.toIntOrNull(), payFrequency = freq, householdSize = household.toIntOrNull(),
                            kidsCount = kids.toIntOrNull(), city = city, dialect = dialect,
                        )
                    )
                )
            }) { Text(stringResource(R.string.save)) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) } },
    )
}

/** اختيار واحد من قايمة، ودوسة تانية على نفس الشريحة بتلغيه (يرجع «مش معروف»). */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ChipGroup(title: String, options: List<String>, selected: String?, onSelect: (String?) -> Unit, label: @Composable (String) -> String) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(title, style = Typography.labelLarge, color = onSurfaceVariant)
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            options.forEach { o ->
                FilterChip(selected = selected == o, onClick = { onSelect(if (selected == o) null else o) }, label = { Text(label(o), style = Typography.labelLarge) })
            }
        }
    }
}
