package com.example.ui.components

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.*
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.material3.Icon as M3Icon
import androidx.compose.material3.IconButton
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import kotlinx.coroutines.flow.StateFlow
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import com.example.R
import com.example.voice.VoiceState
import com.example.voice.ZadCutePetSoundFx
import com.example.voice.ZadVoiceController
import com.example.voice.ZadNaturalVoiceEngine
import com.example.voice.VoiceControllerState
import com.example.voice.ZadVoiceManager
import com.example.ui.theme.*
import com.example.ui.viewmodels.AiChatMessage
import kotlin.math.sin

private const val MAX_TRANSIENT_RETRIES = 3

/**
 * شيت المساعد الصوتي — **مسار واحد** (٢٠٢٦-٠٩-١٤).
 *
 * كان فيه زرار "مكالمة حية / وضع مباشر" بيبدّل بين مسارين، والاتنين كانوا بيقفوا على
 * "تعذّر الاتصال" على جهاز حقيقي. دلوقتي الشيت بيفتح على المكالمة المباشرة (Gemini Live،
 * صوت الشخصية المختارة) على طول، ومفيش اختيار يتعمل.
 *
 * البديل مش وضع يختاره المستخدم: لو المكالمة فشلت بسبب مايوقفش البديل كمان
 * ([VoiceControllerState.Error.canFallBack])، الشيت بيكمّل بنفسه دور-بدور — تعرّف كلام
 * + شات زاد + نفس صوت سارة — مع سطر صغير بيقول ده، وزرار يرجّع للمكالمة المباشرة.
 * يعني زاد بيرد في كل الأحوال بدل ما يسكت على رسالة خطأ.
 */
@OptIn(ExperimentalLayoutApi::class, ExperimentalMaterial3Api::class)
@Composable
fun ZadVoiceBottomSheet(
    viewModel: com.example.ui.viewmodels.ZadViewModel,
    onDismiss: () -> Unit,
) {
    val context = LocalContext.current

    val voiceManager = remember { ZadVoiceManager.apply { init(context) } }
    val voiceController = remember { ZadVoiceController.apply { init(context) } }

    val controllerState by voiceController.state.collectAsState()
    val voiceState by voiceManager.voiceState.collectAsState()
    val isFallbackListening by voiceManager.isListening.collectAsState()
    val currentPersona by voiceManager.currentPersona.collectAsState()

    var fallbackMode by rememberSaveable { mutableStateOf(false) }
    var hasAudioPermission by remember {
        mutableStateOf(
            ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
                PackageManager.PERMISSION_GRANTED
        )
    }
    var recognizedText by remember { mutableStateOf("") }
    var retryAttempt by remember { mutableIntStateOf(0) }
    var activeVoiceTurnId by remember { mutableStateOf<String?>(null) }
    var showSettings by remember { mutableStateOf(false) }

    val liveConnected = controllerState is VoiceControllerState.Listening ||
        controllerState is VoiceControllerState.ModelSpeaking
    val liveConnecting = controllerState is VoiceControllerState.Connecting

    // مصدر حركة الكورة: وزاد بيتكلم = صوته هو، غير كده = المايك.
    val petLevelFlow: StateFlow<Float> = when {
        fallbackMode -> voiceManager.soundLevel
        controllerState is VoiceControllerState.ModelSpeaking -> voiceController.outputLevel
        else -> voiceController.micLevel
    }
    val petAudioLevel = rememberPetAudioLevel(petLevelFlow)
    val waveLevel by petLevelFlow.collectAsState()

    fun startLiveCall() {
        voiceManager.stopListening()
        voiceManager.stopSpeaking()
        voiceController.clearError()
        fallbackMode = false
        voiceController.start(personaId = currentPersona.id)
    }

    fun submitFallbackTurn(text: String) {
        if (text.isBlank() || !fallbackMode) return
        retryAttempt = 0
        recognizedText = text
        voiceManager.markThinking()
        activeVoiceTurnId = viewModel.sendAiChatMessage(text, voiceMode = true)
    }

    fun listenFallback(silent: Boolean = false) {
        voiceManager.startListening(silent = silent) { result -> submitFallbackTurn(result) }
    }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        hasAudioPermission = granted
        if (granted) {
            if (fallbackMode) listenFallback() else startLiveCall()
        }
    }

    // الشيت بيفتح على المكالمة على طول — مرة واحدة لكل فتحة.
    LaunchedEffect(Unit) {
        if (hasAudioPermission) startLiveCall()
        else permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
    }

    // فشل المكالمة → البديل دور-بدور، لو السبب يسمح.
    LaunchedEffect(controllerState) {
        val error = controllerState as? VoiceControllerState.Error ?: return@LaunchedEffect
        if (error.canFallBack && !fallbackMode && hasAudioPermission) {
            fallbackMode = true
            listenFallback()
        }
    }

    // البديل: رد زاد بيتقري بصوت الشخصية، وبعده الاستماع بيرجع لوحده.
    val isTyping by viewModel.isAiTyping.collectAsState()
    val messages by viewModel.aiChatMessages.collectAsState()
    var lastSpokenMessageId by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(isTyping, messages, fallbackMode, activeVoiceTurnId) {
        if (!fallbackMode || isTyping) return@LaunchedEffect
        val lastReply = voiceReplyForTurn(messages, activeVoiceTurnId) ?: return@LaunchedEffect
        if (lastReply.text.isBlank() || lastReply.id == lastSpokenMessageId) return@LaunchedEffect
        lastSpokenMessageId = lastReply.id
        activeVoiceTurnId = null
        voiceManager.stopListening()
        val resume = { if (hasAudioPermission && fallbackMode) listenFallback(silent = true) }
        voiceManager.speakHumanLike(lastReply.text, onDone = resume, onFailed = resume)
    }

    // استئناف بعد أخطاء التعرّف العابرة (NO_MATCH/TIMEOUT عاديين جداً بالعربي) — بسقف.
    LaunchedEffect(voiceState, fallbackMode) {
        if (!fallbackMode) return@LaunchedEffect
        val error = voiceState as? VoiceState.Error ?: return@LaunchedEffect
        if (!error.transient || retryAttempt >= MAX_TRANSIENT_RETRIES) return@LaunchedEffect
        retryAttempt += 1
        kotlinx.coroutines.delay(1200)
        if (hasAudioPermission && voiceManager.voiceState.value == error) listenFallback(silent = true)
    }

    DisposableEffect(Unit) {
        com.example.voice.HeyZadWakeService.pause(context)
        onDispose {
            voiceManager.stopListening()
            voiceManager.stopSpeaking()
            voiceController.stop()
            com.example.voice.HeyZadWakeService.resume(context)
        }
    }

    val petState = when {
        fallbackMode -> when (voiceState) {
            is VoiceState.Listening -> VoicePetState.Listening
            is VoiceState.Thinking -> VoicePetState.Thinking
            is VoiceState.Speaking, is VoiceState.Recognized -> VoicePetState.Speaking
            is VoiceState.Idle -> VoicePetState.Idle
            is VoiceState.Error -> VoicePetState.Sleeping
        }
        else -> when (controllerState) {
            is VoiceControllerState.Listening -> VoicePetState.Listening
            is VoiceControllerState.ModelSpeaking -> VoicePetState.Speaking
            is VoiceControllerState.Connecting -> VoicePetState.Thinking
            is VoiceControllerState.Error -> VoicePetState.Sleeping
            is VoiceControllerState.Idle -> VoicePetState.Idle
        }
    }
    val isSpeaking = if (fallbackMode) voiceState is VoiceState.Speaking
        else controllerState is VoiceControllerState.ModelSpeaking
    val isActive = if (fallbackMode) isFallbackListening || isSpeaking else liveConnected
    val errorMessage = if (fallbackMode) (voiceState as? VoiceState.Error)?.message
        else (controllerState as? VoiceControllerState.Error)?.message

    val quickChips = listOf(
        stringResource(R.string.voice_suggestion_analyze),
        stringResource(R.string.voice_suggestion_meal),
        stringResource(R.string.voice_suggestion_budget),
        stringResource(R.string.voice_suggestion_spend),
    )
    val chipsEnabled = liveConnected || fallbackMode

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = ZadVoiceDarkSheetBg,
        scrimColor = Color.Black.copy(alpha = 0.70f),
        dragHandle = {
            Box(
                modifier = Modifier
                    .padding(vertical = 12.dp)
                    .width(44.dp)
                    .height(4.dp)
                    .clip(RoundedCornerShape(9999.dp))
                    .background(Color.White.copy(alpha = 0.24f))
            )
        },
        shape = RoundedCornerShape(topStart = 32.dp, topEnd = 32.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .navigationBarsPadding()
                .padding(horizontal = 24.dp)
                .padding(bottom = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // ── الترويسة: حالة + إعدادات + قفل. مفيش زرار أوضاع. ──
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier
                        .clip(RoundedCornerShape(9999.dp))
                        .background(Color.White.copy(alpha = 0.08f))
                        .border(1.dp, Color.White.copy(alpha = 0.14f), RoundedCornerShape(9999.dp))
                        .padding(horizontal = 12.dp, vertical = 8.dp)
                ) {
                    val indicatorColor = when {
                        errorMessage != null -> ZadVoiceAlertAmber
                        isSpeaking -> ZadVoiceAlertAmber
                        isActive -> ZadVoiceWaveMint
                        liveConnecting -> ZadVoiceCyan
                        else -> ZadVoiceTextSoft
                    }
                    Box(
                        modifier = Modifier
                            .size(8.dp)
                            .clip(CircleShape)
                            .background(indicatorColor)
                            .then(if (isActive) Modifier.pulseGlow(minScale = 0.85f, maxScale = 1.35f) else Modifier)
                    )
                    Text(
                        text = stringResource(
                            when {
                                liveConnecting -> R.string.voice_header_connecting
                                isSpeaking -> R.string.voice_header_speaking
                                fallbackMode && voiceState is VoiceState.Thinking -> R.string.voice_header_thinking
                                liveConnected -> R.string.voice_header_live
                                else -> R.string.voice_sheet_title
                            }
                        ),
                        style = Typography.labelLarge,
                        fontWeight = FontWeight.Bold,
                        color = Color.White
                    )
                }

                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    SheetIconButton(Icons.Default.Settings, stringResource(R.string.voice_settings_title)) {
                        showSettings = !showSettings
                    }
                    SheetIconButton(Icons.Default.Close, stringResource(R.string.close_action), onDismiss)
                }
            }

            AnimatedVisibility(
                visible = showSettings,
                enter = expandVertically(spring(dampingRatio = 0.85f, stiffness = 380f)) + fadeIn(),
                exit = shrinkVertically(spring(dampingRatio = 0.85f, stiffness = 380f)) + fadeOut(),
            ) {
                SettingsPanel(
                    currentPersonaFlow = voiceManager.currentPersona,
                    onSelect = { persona ->
                        voiceManager.setVoicePersona(persona)
                        // الصوت بيتحدد في setup الجلسة — تغييره وسط مكالمة شغالة = مكالمة جديدة بالصوت الجديد.
                        if (liveConnected || liveConnecting) {
                            voiceController.stop()
                            voiceController.start(personaId = persona.id)
                        }
                    },
                    onDismiss = { showSettings = false }
                )
            }

            ZadVoicePet(
                state = petState,
                size = 128.dp,
                audioLevel = petAudioLevel,
                onClick = { ZadCutePetSoundFx.play(ZadCutePetSoundFx.PetSound.HappyChirp, 0.5f) }
            )

            ZadAudioWavebars(
                isListening = isActive,
                soundLevel = waveLevel,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(48.dp)
            )

            Text(
                text = when {
                    errorMessage != null -> stringResource(R.string.voice_status_error_retry, errorMessage)
                    liveConnecting -> stringResource(R.string.voice_status_connecting)
                    fallbackMode && recognizedText.isNotBlank() && !isFallbackListening -> recognizedText
                    isSpeaking -> stringResource(R.string.voice_status_live_speaking)
                    fallbackMode && voiceState is VoiceState.Thinking -> stringResource(R.string.voice_status_thinking)
                    isActive -> stringResource(R.string.voice_status_live_listening)
                    else -> stringResource(R.string.voice_status_tap_to_start)
                },
                style = Typography.bodyLarge,
                fontWeight = FontWeight.SemiBold,
                color = if (errorMessage != null) ZadVoiceAlertAmber else Color.White,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = 16.dp)
            )

            // البديل شغال: سطر صغير بيقول ليه، وطريق واحد يرجّع للمكالمة المباشرة.
            AnimatedVisibility(visible = fallbackMode, enter = fadeIn(), exit = fadeOut()) {
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(
                        text = stringResource(R.string.voice_fallback_note),
                        style = Typography.bodySmall,
                        color = ZadVoiceTextSoft,
                        textAlign = TextAlign.Center
                    )
                    TextButton(onClick = { startLiveCall() }) {
                        Text(
                            stringResource(R.string.voice_retry_live),
                            style = Typography.labelLarge,
                            fontWeight = FontWeight.Bold,
                            color = ZadVoiceWaveMint
                        )
                    }
                }
            }

            // زرار المايك الوحيد: وقف لو شغال، ابدأ لو واقف.
            Box(
                modifier = Modifier
                    .size(72.dp)
                    .then(if (isActive) Modifier.pulseGlow(minScale = 1f, maxScale = 1.07f) else Modifier)
                    .clip(CircleShape)
                    .background(
                        brush = Brush.radialGradient(
                            colors = when {
                                isSpeaking -> listOf(ZadVoiceAlertAmber, ZadVoiceAlertBrown)
                                isActive -> listOf(ZadVoiceDangerStart, ZadVoiceDangerEnd)
                                else -> listOf(ZadVoiceWaveEmerald, ZadVoiceWaveTealDark)
                            }
                        )
                    )
                    .border(2.dp, Color.White.copy(alpha = 0.35f), CircleShape)
                    .clickable {
                        when {
                            !hasAudioPermission -> permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
                            fallbackMode && (isFallbackListening || isSpeaking) -> {
                                voiceManager.stopListening()
                                voiceManager.stopSpeaking()
                            }
                            fallbackMode -> listenFallback()
                            liveConnected || liveConnecting -> voiceController.stop()
                            else -> startLiveCall()
                        }
                    },
                contentAlignment = Alignment.Center
            ) {
                M3Icon(
                    imageVector = if (isActive || liveConnecting) Icons.Default.Stop else Icons.Default.Mic,
                    contentDescription = stringResource(
                        if (isActive || liveConnecting) R.string.voice_stop_call else R.string.voice_start_call
                    ),
                    tint = Color.White,
                    modifier = Modifier.size(32.dp)
                )
            }

            if (isSpeaking) {
                Text(
                    text = stringResource(R.string.voice_tap_to_interrupt_hint),
                    style = Typography.labelMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = ZadVoiceAlertAmber
                )
            }

            // أسئلة جاهزة: جوه المكالمة المباشرة بتتبعت نص للجلسة نفسها، وفي البديل بتروح للشات.
            AnimatedVisibility(visible = chipsEnabled, enter = fadeIn(), exit = fadeOut()) {
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        text = stringResource(R.string.voice_chips_label),
                        style = Typography.labelMedium,
                        color = ZadVoiceTextSoft
                    )
                    FlowRow(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        quickChips.forEach { chip ->
                            Box(
                                modifier = Modifier
                                    .heightIn(min = 44.dp)
                                    .clip(RoundedCornerShape(9999.dp))
                                    .background(Color.White.copy(alpha = 0.10f))
                                    .border(1.dp, Color.White.copy(alpha = 0.18f), RoundedCornerShape(9999.dp))
                                    .clickable {
                                        if (fallbackMode) submitFallbackTurn(chip) else voiceController.sendText(chip)
                                    }
                                    .padding(horizontal = 16.dp, vertical = 8.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = chip,
                                    style = Typography.labelLarge,
                                    fontWeight = FontWeight.SemiBold,
                                    color = ZadVoiceTextMint
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SheetIconButton(icon: androidx.compose.ui.graphics.vector.ImageVector, description: String, onClick: () -> Unit) {
    IconButton(
        onClick = onClick,
        modifier = Modifier
            .size(44.dp)
            .clip(CircleShape)
            .background(Color.White.copy(alpha = 0.08f))
    ) {
        M3Icon(icon, contentDescription = description, tint = Color.White.copy(alpha = 0.9f), modifier = Modifier.size(20.dp))
    }
}

/**
 * إعدادات الصوت: الشخصية بس. الشخصية دي نفسها بتتبعت للمكالمة المباشرة وبتقرا الإشعارات،
 * فمفيش "صوت للمكالمة" و"صوت للإشعارات" منفصلين.
 */
@Composable
private fun SettingsPanel(
    currentPersonaFlow: StateFlow<ZadNaturalVoiceEngine.VoicePersona>,
    onSelect: (ZadNaturalVoiceEngine.VoicePersona) -> Unit,
    onDismiss: () -> Unit
) {
    val currentPersona by currentPersonaFlow.collectAsState()
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(Color.White.copy(alpha = 0.06f))
            .border(1.dp, Color.White.copy(alpha = 0.12f), RoundedCornerShape(16.dp))
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(stringResource(R.string.voice_settings_title), style = Typography.titleMedium, fontWeight = FontWeight.Bold, color = Color.White)
            IconButton(onClick = onDismiss) {
                M3Icon(Icons.Default.Close, contentDescription = stringResource(R.string.close_action), tint = Color.White.copy(alpha = 0.8f), modifier = Modifier.size(20.dp))
            }
        }
        Text(stringResource(R.string.voice_settings_persona), style = Typography.labelLarge, color = ZadVoiceTextSoft)
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            ZadNaturalVoiceEngine.VoicePersona.values().forEach { persona ->
                val isSelected = currentPersona.id == persona.id
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = 44.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(if (isSelected) ZadVoiceWaveEmerald.copy(alpha = 0.22f) else Color.White.copy(alpha = 0.05f))
                        .border(1.dp, if (isSelected) ZadVoiceWaveEmerald.copy(alpha = 0.55f) else Color.White.copy(alpha = 0.12f), RoundedCornerShape(12.dp))
                        .clickable { onSelect(persona) }
                        .padding(horizontal = 12.dp, vertical = 8.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        persona.displayNameAr,
                        style = Typography.bodyMedium,
                        fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                        color = if (isSelected) ZadVoiceWaveMint else Color.White.copy(alpha = 0.85f)
                    )
                    if (isSelected) {
                        M3Icon(Icons.Default.Check, contentDescription = null, tint = ZadVoiceWaveMint, modifier = Modifier.size(20.dp))
                    }
                }
            }
        }
        Text(stringResource(R.string.voice_settings_info_body), style = Typography.bodySmall, color = ZadVoiceTextSoft)
    }
}

/**
 * Animated Audio Wavebars — مجموعة من 26 بار نحيف مع حركة تموج ونبض طبيعي متناسق الارتفاعات
 */
@Composable
fun ZadAudioWavebars(
    isListening: Boolean,
    soundLevel: Float = 0f,
    modifier: Modifier = Modifier
) {
    val infiniteTransition = rememberInfiniteTransition(label = "wavebars")
    val phase by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = (2 * Math.PI).toFloat(),
        animationSpec = infiniteRepeatable(tween(1400, easing = LinearEasing), RepeatMode.Restart),
        label = "phase"
    )
    
    Canvas(modifier = modifier) {
        val count = 26
        val barWidth = 3.2.dp.toPx()
        val spacing = 3.6.dp.toPx()
        val totalWidth = count * barWidth + (count - 1) * spacing
        val startX = (size.width - totalWidth) / 2f
        val centerY = size.height / 2f
        
        for (i in 0 until count) {
            // Symmetrical parabolic envelope (taller in center, tapering to sides)
            val normDist = (i - (count - 1) / 2f) / ((count - 1) / 2f)
            val envelope = (1f - normDist * normDist * 0.72f).coerceIn(0.25f, 1f)
            
            val wave = sin((phase + i * 0.42f).toDouble()).toFloat()
            val ampBoost = (soundLevel * 1.8f).coerceIn(0f, 1f)
            val dynamicScale = (0.28f + 0.35f * wave + 0.95f * ampBoost).coerceIn(0.12f, 1f)
            
            val multiplier = if (isListening) {
                (envelope * dynamicScale).coerceIn(0.18f, 1f)
            } else {
                (0.12f + 0.06f * wave).coerceIn(0.08f, 0.20f)
            }
            
            val barHeight = (size.height * 0.88f * multiplier).coerceAtLeast(4.dp.toPx())
            val x = startX + i * (barWidth + spacing)
            val y = centerY - barHeight / 2f
            
            drawRoundRect(
                brush = Brush.verticalGradient(
                    colors = if (isListening) {
                        listOf(ZadVoiceWaveMint, ZadVoiceWaveEmerald, ZadVoiceWaveTealDark)
                    } else {
                        listOf(ZadVoiceWaveInactiveTop.copy(alpha = 0.5f), ZadVoiceWaveInactiveBottom.copy(alpha = 0.3f))
                    }
                ),
                topLeft = Offset(x, y),
                size = Size(barWidth, barHeight),
                cornerRadius = CornerRadius(barWidth / 2f, barWidth / 2f)
            )
        }
    }
}


/**
 * Helper to match an AI reply to an active voice turn.
 */
fun voiceReplyForTurn(
    messages: List<AiChatMessage>,
    activeTurnMessageId: String?
): AiChatMessage? {
    if (activeTurnMessageId.isNullOrBlank()) return null
    return messages.lastOrNull { !it.isUser && it.replyToMessageId == activeTurnMessageId }
}