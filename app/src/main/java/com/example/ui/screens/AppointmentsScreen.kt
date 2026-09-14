package com.example.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.DirectionsWalk
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.example.R
import com.example.data.APPOINTMENT_KINDS
import com.example.data.AppointmentGroup
import com.example.data.GroceryGeofenceManager
import com.example.data.PLACE_REMINDER_PLACES
import com.example.data.ZadPlaceReminder
import com.example.data.SupabaseRepo
import com.example.data.ZadAppointment
import com.example.data.groupAppointments
import com.example.data.startInstant
import com.example.ui.components.ZadEmptyState
import com.example.ui.components.ZadSprings
import com.example.ui.components.pressableScale
import com.example.ui.theme.*
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

/**
 * مواعيدي — مواعيد ومشاوير والتزامات غير مالية (طلب المستخدم ٢٠٢٦-٠٩-١٤).
 *
 * المصدر `zad_appointments`. أغلب المواعيد المتوقع تتسجّل بالكلام («فكّريني بكرة الساعة ٥
 * أروح البنك») من المكالمة أو الشات أو تليجرام — العقل بيسجّلها بـ add_appointment — فالكارت
 * اللي فوق بيعلّم ده بدل ما يخلّي الفورم هو الطريق الوحيد. التذكير نفسه بيجي من السيرفر
 * بصوت زاد (موبايل + تليجرام)، مش من منبّه على الجهاز.
 *
 * مفيش LLM هنا: الشاشة بتقرا الجدول بس (قاعدة "No LLM call on screen open").
 */
@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun AppointmentsScreen(
    onOpenVoice: () -> Unit,
    onOpenObligations: () -> Unit,
) {
    val scope = rememberCoroutineScope()
    var items by remember { mutableStateOf<List<ZadAppointment>?>(null) }
    var loadFailed by remember { mutableStateOf(false) }
    var loading by remember { mutableStateOf(true) }
    var showAdd by remember { mutableStateOf(false) }
    var showPast by rememberSaveable { mutableStateOf(false) }
    var actionTarget by remember { mutableStateOf<ZadAppointment?>(null) }
    var reloadKey by remember { mutableIntStateOf(0) }
    var placeReminders by remember { mutableStateOf<List<ZadPlaceReminder>>(emptyList()) }
    var showAddPlace by remember { mutableStateOf(false) }
    val context = androidx.compose.ui.platform.LocalContext.current
    val locationAlertsOn = remember(reloadKey) { GroceryGeofenceManager.isEnabled(context) }

    LaunchedEffect(reloadKey) {
        loading = true
        val result = SupabaseRepo.getAppointments()
        loadFailed = result == null
        if (result != null) items = result
        SupabaseRepo.getPlaceReminders()?.let { placeReminders = it }
        loading = false
    }

    val groups = remember(items) { groupAppointments(items.orEmpty(), ZonedDateTime.now()) }

    Box(Modifier.fillMaxSize()) {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 8.dp, bottom = ZadHubListBottomPadding),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item(key = "voice") { VoiceHintCard(onOpenVoice) }
            item(key = "obligations") { ObligationsLink(onOpenObligations) }
            item(key = "place-reminders") {
                PlaceRemindersSection(
                    reminders = placeReminders,
                    locationAlertsOn = locationAlertsOn,
                    onAdd = { showAddPlace = true },
                    onCancel = { r ->
                        scope.launch { if (SupabaseRepo.cancelPlaceReminder(r.id)) reloadKey++ }
                    },
                )
            }

            when {
                loading && items == null -> item(key = "loading") {
                    Box(Modifier.fillMaxWidth().padding(vertical = 48.dp), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(color = primary)
                    }
                }
                loadFailed && items == null -> item(key = "error") {
                    ZadEmptyState(
                        title = stringResource(R.string.appointments_load_failed),
                        icon = Icons.Default.CloudOff,
                        modifier = Modifier.fillMaxWidth().padding(vertical = 32.dp),
                        action = {
                            OutlinedButton(onClick = { reloadKey++ }, modifier = Modifier.heightIn(min = 44.dp)) {
                                Text(stringResource(R.string.appointments_retry))
                            }
                        },
                    )
                }
                groups.none { it.first != AppointmentGroup.PAST } -> item(key = "empty") {
                    ZadEmptyState(
                        title = stringResource(R.string.appointments_empty_title),
                        subtitle = stringResource(R.string.appointments_empty_subtitle),
                        icon = Icons.Default.EventAvailable,
                        modifier = Modifier.fillMaxWidth().padding(vertical = 24.dp),
                        action = {
                            Button(onClick = { showAdd = true }, modifier = Modifier.heightIn(min = 44.dp)) {
                                Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(18.dp))
                                Spacer(Modifier.width(8.dp))
                                Text(stringResource(R.string.appointments_add))
                            }
                        },
                    )
                }
            }

            groups.forEach { (group, list) ->
                if (group == AppointmentGroup.PAST) {
                    item(key = "past-header") {
                        PastHeader(count = list.size, expanded = showPast, onToggle = { showPast = !showPast })
                    }
                    item(key = "past-list") {
                        AnimatedVisibility(
                            visible = showPast,
                            enter = expandVertically(spring(dampingRatio = 0.85f, stiffness = 380f)) + fadeIn(),
                            exit = shrinkVertically(spring(dampingRatio = 0.85f, stiffness = 380f)) + fadeOut(),
                        ) {
                            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                list.forEach { AppointmentRow(it, past = true, onClick = { actionTarget = it }, onDone = null) }
                            }
                        }
                    }
                } else {
                    item(key = "header-${group.name}") {
                        Text(
                            text = stringResource(groupLabel(group)),
                            style = Typography.titleSmall,
                            fontWeight = FontWeight.Bold,
                            color = onSurface,
                            modifier = Modifier.padding(top = 8.dp),
                        )
                    }
                    items(list, key = { it.id }) { appt ->
                        AppointmentRow(
                            appointment = appt,
                            past = false,
                            onClick = { actionTarget = appt },
                            onDone = {
                                scope.launch {
                                    if (SupabaseRepo.setAppointmentStatus(appt.id, "done")) reloadKey++
                                }
                            },
                        )
                    }
                }
            }
        }

        ExtendedFloatingActionButton(
            onClick = { showAdd = true },
            icon = { Icon(Icons.Default.Add, contentDescription = null) },
            text = { Text(stringResource(R.string.appointments_add)) },
            containerColor = primary,
            contentColor = onPrimary,
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(end = 16.dp, bottom = 24.dp)
                .pressableScale(),
        )
    }

    if (showAddPlace) {
        AddPlaceReminderDialog(
            onDismiss = { showAddPlace = false },
            onSaved = {
                showAddPlace = false
                reloadKey++
            },
        )
    }

    if (showAdd) {
        AddAppointmentDialog(
            onDismiss = { showAdd = false },
            onSaved = {
                showAdd = false
                reloadKey++
            },
        )
    }

    actionTarget?.let { target ->
        AlertDialog(
            onDismissRequest = { actionTarget = null },
            title = { Text(target.title, style = Typography.titleMedium, fontWeight = FontWeight.Bold) },
            text = { Text(appointmentWhenText(target), style = Typography.bodyMedium, color = onSurfaceVariant) },
            confirmButton = {
                if (target.status == "upcoming") {
                    TextButton(onClick = {
                        scope.launch {
                            SupabaseRepo.setAppointmentStatus(target.id, "cancelled")
                            actionTarget = null
                            reloadKey++
                        }
                    }) { Text(stringResource(R.string.appointments_cancel_it), color = dangerColor) }
                }
            },
            dismissButton = {
                TextButton(onClick = {
                    scope.launch {
                        SupabaseRepo.deleteAppointment(target.id)
                        actionTarget = null
                        reloadKey++
                    }
                }) { Text(stringResource(R.string.delete_action)) }
            },
        )
    }
}

@Composable
private fun VoiceHintCard(onOpenVoice: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(primaryContainer)
            .clickable(onClick = onOpenVoice)
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Box(
            modifier = Modifier.size(48.dp).clip(CircleShape).background(primary),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Default.Mic, contentDescription = null, tint = onPrimary, modifier = Modifier.size(24.dp))
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                stringResource(R.string.appointments_voice_hint_title),
                style = Typography.titleSmall,
                fontWeight = FontWeight.Bold,
                color = onPrimaryContainer,
            )
            Text(
                stringResource(R.string.appointments_voice_hint_example),
                style = Typography.bodySmall,
                color = onPrimaryContainer,
            )
        }
    }
}

@Composable
private fun ObligationsLink(onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 44.dp)
            .clip(RoundedCornerShape(16.dp))
            .border(1.dp, outlineVariant, RoundedCornerShape(16.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(Icons.Default.ReceiptLong, contentDescription = null, tint = onSurfaceVariant, modifier = Modifier.size(20.dp))
        Text(
            stringResource(R.string.appointments_obligations_link),
            style = Typography.bodyMedium,
            color = onSurface,
            modifier = Modifier.weight(1f),
        )
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowLeft, contentDescription = null, tint = onSurfaceVariant)
    }
}

/**
 * «لما توصل مكان» — تذكيرات من غير وقت. من غير تنبيهات الموقع مفيش store_arrival أصلاً،
 * فبنقولها صريحة بدل ما العميل يستنى تذكير عمره ما هيتقال.
 */
@Composable
private fun PlaceRemindersSection(
    reminders: List<ZadPlaceReminder>,
    locationAlertsOn: Boolean,
    onAdd: () -> Unit,
    onCancel: (ZadPlaceReminder) -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(surface)
            .border(1.dp, outlineVariant, RoundedCornerShape(20.dp))
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Icon(Icons.Default.Place, contentDescription = null, tint = primary, modifier = Modifier.size(20.dp))
            Text(
                stringResource(R.string.place_reminders_title),
                style = Typography.titleSmall,
                fontWeight = FontWeight.Bold,
                color = onSurface,
                modifier = Modifier.weight(1f),
            )
            TextButton(onClick = onAdd, modifier = Modifier.heightIn(min = 44.dp)) {
                Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(4.dp))
                Text(stringResource(R.string.place_reminders_add))
            }
        }
        if (reminders.isEmpty()) {
            Text(stringResource(R.string.place_reminders_hint), style = Typography.bodySmall, color = onSurfaceVariant)
        } else {
            reminders.forEach { r ->
                Row(
                    modifier = Modifier.fillMaxWidth().heightIn(min = 44.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    val accent = placeAccent(r.place)
                    Box(
                        modifier = Modifier.size(36.dp).clip(RoundedCornerShape(10.dp)).background(accent.containerColor),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(placeIcon(r.place), contentDescription = null, tint = accent.contentColor, modifier = Modifier.size(18.dp))
                    }
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text(r.note, style = Typography.bodyMedium, fontWeight = FontWeight.SemiBold, color = onSurface, maxLines = 2, overflow = TextOverflow.Ellipsis)
                        Text(stringResource(placeLabel(r.place)), style = Typography.bodySmall, color = onSurfaceVariant)
                    }
                    IconButton(onClick = { onCancel(r) }) {
                        Icon(Icons.Default.Close, contentDescription = stringResource(R.string.place_reminder_remove_cd), tint = onSurfaceVariant)
                    }
                }
            }
        }
        if (!locationAlertsOn) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Icon(Icons.Default.LocationOff, contentDescription = null, tint = warningColor, modifier = Modifier.size(16.dp))
                Text(stringResource(R.string.place_reminders_location_off), style = Typography.bodySmall, color = onSurfaceVariant)
            }
        }
    }
}

private fun placeLabel(place: String): Int = when (place) {
    "pharmacy" -> R.string.place_kind_pharmacy
    "supermarket" -> R.string.place_kind_supermarket
    "mall" -> R.string.place_kind_mall
    else -> R.string.place_kind_any
}

private fun placeIcon(place: String): ImageVector = when (place) {
    "pharmacy" -> Icons.Default.LocalPharmacy
    "supermarket" -> Icons.Default.ShoppingCart
    "mall" -> Icons.Default.LocalMall
    else -> Icons.Default.Storefront
}

private fun placeAccent(place: String): ZadSectionAccent = when (place) {
    "pharmacy" -> ZadSectionAccent.Rose
    "supermarket" -> ZadSectionAccent.Emerald
    "mall" -> ZadSectionAccent.Violet
    else -> ZadSectionAccent.Amber
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun AddPlaceReminderDialog(onDismiss: () -> Unit, onSaved: () -> Unit) {
    val scope = rememberCoroutineScope()
    var note by rememberSaveable { mutableStateOf("") }
    var place by rememberSaveable { mutableStateOf("pharmacy") }
    var saving by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val failMessage = stringResource(R.string.appointments_save_failed)

    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = surface,
        title = { Text(stringResource(R.string.place_reminders_add), style = Typography.titleLarge, fontWeight = FontWeight.Bold) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedTextField(
                    value = note,
                    onValueChange = { note = it.take(200) },
                    label = { Text(stringResource(R.string.place_reminder_field_note)) },
                    singleLine = true,
                    colors = OutlinedTextFieldDefaults.colors(
                        unfocusedBorderColor = onSurfaceVariant.copy(alpha = 0.72f),
                        focusedBorderColor = primary,
                    ),
                    modifier = Modifier.fillMaxWidth(),
                )
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    PLACE_REMINDER_PLACES.forEach { p ->
                        FilterChip(
                            selected = place == p,
                            onClick = { place = p },
                            label = { Text(stringResource(placeLabel(p)), style = Typography.labelLarge) },
                            leadingIcon = { Icon(placeIcon(p), contentDescription = null, modifier = Modifier.size(16.dp)) },
                        )
                    }
                }
                AnimatedVisibility(visible = error != null) {
                    Text(error.orEmpty(), style = Typography.bodySmall, color = dangerColor)
                }
            }
        },
        confirmButton = {
            Button(
                enabled = note.trim().length >= 2 && !saving,
                onClick = {
                    saving = true
                    error = null
                    scope.launch {
                        val ok = SupabaseRepo.addPlaceReminder(note, place)
                        saving = false
                        if (ok) onSaved() else error = failMessage
                    }
                },
            ) { Text(stringResource(R.string.save)) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) } },
    )
}

@Composable
private fun PastHeader(count: Int, expanded: Boolean, onToggle: () -> Unit) {
    val rotation by animateFloatAsState(if (expanded) 180f else 0f, ZadSprings.Screen, label = "pastChevron")
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 44.dp)
            .clip(RoundedCornerShape(12.dp))
            .clickable(onClick = onToggle)
            .padding(top = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            stringResource(R.string.appointments_group_past, count),
            style = Typography.titleSmall,
            fontWeight = FontWeight.Bold,
            color = onSurfaceVariant,
            modifier = Modifier.weight(1f),
        )
        Icon(Icons.Default.ExpandMore, contentDescription = null, tint = onSurfaceVariant, modifier = Modifier.rotate(rotation))
    }
}

@Composable
private fun AppointmentRow(
    appointment: ZadAppointment,
    past: Boolean,
    onClick: () -> Unit,
    onDone: (() -> Unit)?,
) {
    val accent = kindAccent(appointment.kind)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(surface)
            .border(1.dp, outlineVariant, RoundedCornerShape(16.dp))
            .clickable(onClick = onClick)
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(
            modifier = Modifier.size(44.dp).clip(RoundedCornerShape(12.dp)).background(accent.containerColor),
            contentAlignment = Alignment.Center,
        ) {
            Icon(kindIcon(appointment.kind), contentDescription = null, tint = accent.contentColor, modifier = Modifier.size(22.dp))
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                appointment.title,
                style = Typography.bodyLarge,
                fontWeight = FontWeight.SemiBold,
                color = if (past) onSurfaceVariant else onSurface,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                appointmentWhenText(appointment),
                style = Typography.bodySmall,
                color = onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        if (onDone != null) {
            IconButton(onClick = onDone) {
                Icon(Icons.Default.CheckCircleOutline, contentDescription = stringResource(R.string.appointments_mark_done), tint = primary)
            }
        } else if (appointment.status == "done") {
            Icon(Icons.Default.CheckCircle, contentDescription = null, tint = primary, modifier = Modifier.size(24.dp))
        }
    }
}

@Composable
private fun appointmentWhenText(a: ZadAppointment): String {
    val at = a.startInstant()?.atZone(ZoneId.systemDefault()) ?: return a.startsAt
    val date = at.format(DateTimeFormatter.ofPattern("EEEE d MMM"))
    val time = at.format(DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT))
    val parts = mutableListOf("$date · $time")
    a.placeLabel?.takeIf { it.isNotBlank() }?.let { parts += it }
    if (a.recurrence != "once") parts += stringResource(recurrenceLabel(a.recurrence))
    return parts.joinToString(" · ")
}

private fun groupLabel(g: AppointmentGroup): Int = when (g) {
    AppointmentGroup.TODAY -> R.string.appointments_group_today
    AppointmentGroup.TOMORROW -> R.string.appointments_group_tomorrow
    AppointmentGroup.THIS_WEEK -> R.string.appointments_group_week
    AppointmentGroup.LATER -> R.string.appointments_group_later
    AppointmentGroup.PAST -> R.string.appointments_group_past
}

private fun kindLabel(kind: String): Int = when (kind) {
    "work" -> R.string.appointment_kind_work
    "errand" -> R.string.appointment_kind_errand
    "medical" -> R.string.appointment_kind_medical
    "family" -> R.string.appointment_kind_family
    "personal" -> R.string.appointment_kind_personal
    else -> R.string.appointment_kind_other
}

private fun recurrenceLabel(r: String): Int = when (r) {
    "daily" -> R.string.appointment_repeat_daily
    "weekly" -> R.string.appointment_repeat_weekly
    "monthly" -> R.string.appointment_repeat_monthly
    else -> R.string.appointment_repeat_once
}

private fun kindIcon(kind: String): ImageVector = when (kind) {
    "work" -> Icons.Default.Work
    "errand" -> Icons.AutoMirrored.Filled.DirectionsWalk
    "medical" -> Icons.Default.LocalHospital
    "family" -> Icons.Default.FamilyRestroom
    "personal" -> Icons.Default.Person
    else -> Icons.Default.Event
}

private fun kindAccent(kind: String): ZadSectionAccent = when (kind) {
    "work" -> ZadSectionAccent.Blue
    "errand" -> ZadSectionAccent.Amber
    "medical" -> ZadSectionAccent.Rose
    "family" -> ZadSectionAccent.Violet
    "personal" -> ZadSectionAccent.Emerald
    else -> ZadSectionAccent.Slate
}

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
private fun AddAppointmentDialog(onDismiss: () -> Unit, onSaved: () -> Unit) {
    val scope = rememberCoroutineScope()
    val zone = remember { ZoneId.systemDefault() }
    val nowLocal = remember { ZonedDateTime.now(zone) }
    var title by rememberSaveable { mutableStateOf("") }
    var kind by rememberSaveable { mutableStateOf("personal") }
    var date by remember { mutableStateOf(nowLocal.toLocalDate()) }
    var time by remember { mutableStateOf(LocalTime.of((nowLocal.hour + 1) % 24, 0)) }
    var place by rememberSaveable { mutableStateOf("") }
    var remind by rememberSaveable { mutableIntStateOf(30) }
    var recurrence by rememberSaveable { mutableStateOf("once") }
    var showDate by remember { mutableStateOf(false) }
    var showTime by remember { mutableStateOf(false) }
    var saving by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }

    val fieldColors = OutlinedTextFieldDefaults.colors(
        unfocusedBorderColor = onSurfaceVariant.copy(alpha = 0.72f),
        focusedBorderColor = primary,
    )
    val startsAt = ZonedDateTime.of(date, time, zone)
    val inPast = startsAt.isBefore(ZonedDateTime.now(zone))
    val pastMessage = stringResource(R.string.appointments_time_in_past)
    val failMessage = stringResource(R.string.appointments_save_failed)

    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = surface,
        title = { Text(stringResource(R.string.appointments_add), style = Typography.titleLarge, fontWeight = FontWeight.Bold) },
        text = {
            Column(
                modifier = Modifier.heightIn(max = 480.dp).verticalScroll(rememberScrollState()).imePadding(),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                OutlinedTextField(
                    value = title,
                    onValueChange = { title = it.take(160) },
                    label = { Text(stringResource(R.string.appointments_field_title)) },
                    singleLine = true,
                    colors = fieldColors,
                    modifier = Modifier.fillMaxWidth(),
                )
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    APPOINTMENT_KINDS.forEach { k ->
                        FilterChip(
                            selected = kind == k,
                            onClick = { kind = k },
                            label = { Text(stringResource(kindLabel(k)), style = Typography.labelLarge) },
                            leadingIcon = { Icon(kindIcon(k), contentDescription = null, modifier = Modifier.size(16.dp)) },
                        )
                    }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(onClick = { showDate = true }, modifier = Modifier.weight(1f).heightIn(min = 44.dp)) {
                        Icon(Icons.Default.CalendarMonth, contentDescription = null, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.width(8.dp))
                        Text(date.format(DateTimeFormatter.ofPattern("EEE d MMM")), maxLines = 1)
                    }
                    OutlinedButton(onClick = { showTime = true }, modifier = Modifier.weight(1f).heightIn(min = 44.dp)) {
                        Icon(Icons.Default.Schedule, contentDescription = null, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.width(8.dp))
                        Text(time.format(DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT)), maxLines = 1)
                    }
                }
                OutlinedTextField(
                    value = place,
                    onValueChange = { place = it.take(120) },
                    label = { Text(stringResource(R.string.appointments_field_place)) },
                    singleLine = true,
                    colors = fieldColors,
                    modifier = Modifier.fillMaxWidth(),
                )
                Text(stringResource(R.string.appointments_remind_before), style = Typography.labelLarge, color = onSurfaceVariant)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    listOf(15, 30, 60, 120).forEach { m ->
                        FilterChip(
                            selected = remind == m,
                            onClick = { remind = m },
                            label = { Text(stringResource(R.string.appointments_minutes_fmt, m), style = Typography.labelLarge) },
                        )
                    }
                }
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    listOf("once", "daily", "weekly", "monthly").forEach { r ->
                        FilterChip(
                            selected = recurrence == r,
                            onClick = { recurrence = r },
                            label = { Text(stringResource(recurrenceLabel(r)), style = Typography.labelLarge) },
                        )
                    }
                }
                AnimatedVisibility(visible = error != null || (inPast && recurrence == "once")) {
                    Text(error ?: pastMessage, style = Typography.bodySmall, color = dangerColor)
                }
            }
        },
        confirmButton = {
            Button(
                enabled = title.trim().length >= 2 && !saving && !(inPast && recurrence == "once"),
                onClick = {
                    saving = true
                    error = null
                    scope.launch {
                        val ok = SupabaseRepo.addAppointment(
                            title = title,
                            kind = kind,
                            startsAtIso = startsAt.toOffsetDateTime().toString(),
                            placeLabel = place,
                            remindMinutesBefore = remind,
                            recurrence = recurrence,
                        )
                        saving = false
                        if (ok) onSaved() else error = failMessage
                    }
                },
            ) { Text(stringResource(R.string.save)) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) } },
    )

    if (showDate) {
        val state = rememberDatePickerState(
            initialSelectedDateMillis = date.atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli()
        )
        DatePickerDialog(
            onDismissRequest = { showDate = false },
            confirmButton = {
                TextButton(onClick = {
                    state.selectedDateMillis?.let { date = Instant.ofEpochMilli(it).atZone(ZoneOffset.UTC).toLocalDate() }
                    showDate = false
                }) { Text(stringResource(R.string.save)) }
            },
            dismissButton = { TextButton(onClick = { showDate = false }) { Text(stringResource(R.string.cancel)) } },
        ) { DatePicker(state = state) }
    }
    if (showTime) {
        val state = rememberTimePickerState(initialHour = time.hour, initialMinute = time.minute)
        AlertDialog(
            onDismissRequest = { showTime = false },
            containerColor = surface,
            text = { TimePicker(state = state) },
            confirmButton = {
                TextButton(onClick = {
                    time = LocalTime.of(state.hour, state.minute)
                    showTime = false
                }) { Text(stringResource(R.string.save)) }
            },
            dismissButton = { TextButton(onClick = { showTime = false }) { Text(stringResource(R.string.cancel)) } },
        )
    }
}
