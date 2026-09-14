package com.example.ui.components

import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.PersonAdd
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.example.R
import com.example.data.OrbAccessory
import com.example.data.OrbAccessoryStore
import com.example.ui.theme.*

/**
 * «زيّن زاد» — الزينة المفتوحة والمقفولة بعدد أفراد العيلة، وزرار دعوة. كل خانة معاينة حية
 * للكورة بالزينة دي (مش صورة ثابتة).
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun OrbAccessoryPickerDialog(
    familySize: Int,
    inviteCode: String?,
    onInvite: () -> Unit,
    onDismiss: () -> Unit,
) {
    val context = LocalContext.current
    val next = OrbAccessory.nextLocked(familySize)
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = surface,
        title = { Text(stringResource(R.string.orb_picker_title), style = Typography.titleLarge, fontWeight = FontWeight.Bold) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(
                    next?.let { stringResource(R.string.orb_picker_next, it.familySizeNeeded - familySize, stringResource(accessoryLabel(it))) }
                        ?: stringResource(R.string.orb_picker_all_unlocked),
                    style = Typography.bodyMedium,
                    color = onSurfaceVariant,
                )
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    OrbAccessory.entries.forEach { acc ->
                        val unlocked = acc.isUnlocked(familySize)
                        val selected = OrbAccessoryStore.current == acc
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            modifier = Modifier
                                .width(84.dp)
                                .clip(RoundedCornerShape(16.dp))
                                .border(if (selected) 2.dp else 1.dp, if (selected) primary else outlineVariant, RoundedCornerShape(16.dp))
                                .clickable(enabled = unlocked) { OrbAccessoryStore.select(context, acc, familySize) }
                                .padding(8.dp),
                        ) {
                            Box(contentAlignment = Alignment.Center) {
                                CompanionOrb(state = CompanionState.Happy, size = 56.dp, animated = false, accessory = acc)
                                if (!unlocked) Icon(Icons.Default.Lock, contentDescription = null, tint = onSurfaceVariant, modifier = Modifier.size(20.dp))
                            }
                            Text(stringResource(accessoryLabel(acc)), style = Typography.labelMedium, color = onSurface, textAlign = TextAlign.Center)
                            if (!unlocked) {
                                Text(stringResource(R.string.orb_picker_needs, acc.familySizeNeeded), style = Typography.labelSmall, color = onSurfaceVariant, textAlign = TextAlign.Center)
                            }
                        }
                    }
                }
            }
        },
        confirmButton = {
            Button(onClick = onInvite, modifier = Modifier.heightIn(min = 44.dp)) {
                Icon(Icons.Default.PersonAdd, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(8.dp))
                Text(stringResource(if (inviteCode != null) R.string.orb_picker_invite else R.string.orb_picker_create_family))
            }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) } },
    )
}

fun accessoryLabel(a: OrbAccessory): Int = when (a) {
    OrbAccessory.NONE -> R.string.orb_accessory_none
    OrbAccessory.BOW -> R.string.orb_accessory_bow
    OrbAccessory.GLASSES -> R.string.orb_accessory_glasses
    OrbAccessory.FLOWER -> R.string.orb_accessory_flower
    OrbAccessory.CROWN -> R.string.orb_accessory_crown
}
