package com.example.ui.components

import android.content.Context
import android.widget.Toast
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.WavingHand
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.example.R
import com.example.data.SupabaseRepo
import com.example.data.ZadCustomerProfile
import com.example.data.needsIntroduction
import com.example.ui.theme.*
import kotlinx.coroutines.launch

/**
 * ملف العميل خارج شاشة الذاكرة (٢٠٢٦-٠٩-١٤). بلاغ من تجربة حقيقية: «التطبيق مايعرفش أنا مين،
 * مفيش بروفايل خاص بيا». الملف كان موجود — بس جوه «ذاكرة زاد» بس، تلات خطوات تحت، فعملياً
 * محدش بيلاقيه. دلوقتي بيظهر في صفحة البروفايل، وكارت «عرّفني بنفسك» في الرئيسية لحد ما الاسم
 * والنوع يتعرفوا.
 */
private class ProfileState {
    var loaded by mutableStateOf(false)
    var failed by mutableStateOf(false)
    var profile by mutableStateOf<ZadCustomerProfile?>(null)
    var editing by mutableStateOf(false)
    var saving by mutableStateOf(false)
}

@Composable
private fun rememberProfileState(): ProfileState {
    val state = remember { ProfileState() }
    LaunchedEffect(Unit) {
        SupabaseRepo.loadCustomerProfile()
            .onSuccess { state.profile = it; state.loaded = true }
            .onFailure { state.failed = true }
    }
    return state
}

@Composable
private fun ProfileEditor(state: ProfileState, fallbackName: String?, onSaved: () -> Unit = {}) {
    if (!state.editing) return
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val failedText = stringResource(R.string.profile_save_failed)
    CustomerProfileDialog(
        // الاسم اللي العميل كتبه وقت التسجيل بيبقى نقطة البداية لو الملف لسه مالوش اسم.
        initial = (state.profile ?: ZadCustomerProfile()).let {
            if (it.preferredName.isNullOrBlank() && !fallbackName.isNullOrBlank()) it.copy(preferredName = fallbackName) else it
        },
        saving = state.saving,
        onDismiss = { state.editing = false },
        onSave = { updated ->
            state.saving = true
            scope.launch {
                val ok = SupabaseRepo.saveCustomerProfile(updated)
                state.saving = false
                if (ok) {
                    state.profile = SupabaseRepo.loadCustomerProfile().getOrNull() ?: updated
                    state.editing = false
                    onSaved()
                } else {
                    Toast.makeText(context, failedText, Toast.LENGTH_LONG).show()
                }
            }
        },
    )
}

/** صفحة البروفايل: «إنت مين عند زاد» دايماً ظاهر، بزرار تعديل. */
@Composable
fun CustomerProfileSection(fallbackName: String?, modifier: Modifier = Modifier) {
    val state = rememberProfileState()
    // قبل ما القراءة تنجح مفيش كارت: فورم فاضية بعد قراءة فاشلة كانت هتمسح الملف عند الحفظ.
    if (!state.loaded) return
    CustomerProfileCard(profile = state.profile, onEdit = { state.editing = true }, modifier = modifier)
    ProfileEditor(state, fallbackName)
}

private const val PREFS = "zad_prefs"
private const val KEY_INTRO_DISMISSED = "who_are_you_card_dismissed"

/** الرئيسية: «عرّفني بنفسك» — بيختفي لما الاسم والنوع يتعرفوا أو العميل يقول «بعدين». */
@Composable
fun WhoAreYouCard(fallbackName: String?, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val prefs = remember { context.getSharedPreferences(PREFS, Context.MODE_PRIVATE) }
    var dismissed by remember { mutableStateOf(prefs.getBoolean(KEY_INTRO_DISMISSED, false)) }
    if (dismissed) return
    val state = rememberProfileState()
    if (!state.loaded || !needsIntroduction(state.profile)) {
        ProfileEditor(state, fallbackName)
        return
    }
    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .border(1.dp, outlineVariant, RoundedCornerShape(20.dp))
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Icon(Icons.Default.WavingHand, contentDescription = null, tint = primary, modifier = Modifier.size(24.dp))
            Column(Modifier.weight(1f)) {
                Text(stringResource(R.string.who_are_you_title), style = Typography.titleSmall, fontWeight = FontWeight.Bold, color = onSurface)
                Text(stringResource(R.string.who_are_you_body), style = Typography.bodySmall, color = onSurfaceVariant)
            }
        }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(onClick = { state.editing = true }, modifier = Modifier.heightIn(min = 44.dp)) {
                Text(stringResource(R.string.who_are_you_cta))
            }
            Spacer(Modifier.weight(1f))
            TextButton(
                onClick = {
                    dismissed = true
                    prefs.edit().putBoolean(KEY_INTRO_DISMISSED, true).apply()
                },
                modifier = Modifier.heightIn(min = 44.dp),
            ) { Text(stringResource(R.string.later_action), color = onSurfaceVariant) }
        }
    }
    ProfileEditor(state, fallbackName)
}
