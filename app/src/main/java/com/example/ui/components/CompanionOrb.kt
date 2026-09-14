package com.example.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.example.R
import com.example.voice.VoiceControllerState
import com.example.voice.ZadCutePetSoundFx
import com.example.voice.VoiceState
import com.example.ui.theme.*
import kotlinx.coroutines.delay
import kotlin.math.cos
import kotlin.math.sin
import kotlin.random.Random

/**
 * حالة الأيجنت العاطفية — كل حالة بتحدد لون الكورة وشكل العيون.
 * زمردي: عادي/هادئ. سماوي: بيسمع. بنفسجي: مركّز/بيحلل. أزرق: بيتكلم.
 * أخضر فاتح: سعيد/إنجاز. أحمر: تنبيه. دهبي: احتفال.
 *
 * الألوان دي **هوية**، مش توكنات ثيم، ومقصود إنها ثابتة بين اللايت والدارك:
 * "أحمر = تنبيه" لازم يفضل أحمر زي ما شعار مابيتغيّرش. اللي بيتجاوب مع الثيم هو
 * الهالة حوالين الكورة، لأنها مرسومة بشفافية فبتتركّب فوق أرضية الصفحة.
 *
 * Listening/Speaking اتضافوا وقت توحيد الأفاتار (كانوا في ZadBotEmotion المتوازي).
 * سماوي وأزرق لأنهم لازم يتفرقوا عن الخمسة اللي فاتوا وعن بعض — دول لحظتا الإدخال
 * والإخراج في نفس المكالمة والمستخدم بيفرّق بينهم بالنظر.
 */
enum class CompanionState(val skyColor: Color, val deepColor: Color) {
    Idle(ZadOrbIdleSky, ZadOrbIdleDeep),
    Listening(ZadOrbListeningSky, ZadOrbListeningDeep),
    Focused(ZadOrbFocusedSky, ZadOrbFocusedDeep),
    Speaking(ZadOrbSpeakingSky, ZadOrbSpeakingDeep),
    Happy(ZadOrbHappySky, ZadOrbHappyDeep),
    Alert(ZadOrbAlertSky, ZadOrbAlertDeep),
    Celebrating(ZadOrbCelebratingSky, ZadOrbCelebratingDeep)
}

/**
 * ترجمة حالة الصوت لمزاج — أو null لو الصوت مش شغال.
 *
 * null معناها "مالكش دعوة"، **مش** "هادئ". ساعتها المزاج بيرجع للمسار الذكي
 * (شات/تنبيهات). لو رجّعنا Idle هنا، الصوت الخامل كان هيدهس تنبيه ميزانية متجاوزة
 * وتقعد الكورة تقول "هادئ" — والفرق ده مابيكسرش أي بناء، عشان كده متغطّى بتست.
 *
 * دالة نقية على مستوى الملف مش ميثود في الـViewModel: ZadViewModel مايتعملش منه
 * نسخة في تست JVM (SQLCipher محتاج مكتبة أصلية — نفس السبب اللي HomeScreenTest
 * متعلّم بيه @Ignore)، فحطّها هناك كان معناه إنها مستحيلة الاختبار.
 */
fun companionMoodForVoice(voice: VoiceState): CompanionState? = when (voice) {
    is VoiceState.Listening -> CompanionState.Listening
    is VoiceState.Thinking -> CompanionState.Focused
    is VoiceState.Speaking -> CompanionState.Speaking
    is VoiceState.Recognized -> CompanionState.Happy
    is VoiceState.Idle, is VoiceState.Error -> null
}

/**
 * نفس القاعدة للمكالمة الحية. Connecting → Focused لأن الاتصال شغل بيحصل ورا
 * الكواليس والمستخدم مستني — نفس معنى "بيفكر" بالظبط.
 */
fun companionMoodForLiveVoice(live: VoiceControllerState): CompanionState? = when (live) {
    is VoiceControllerState.Listening -> CompanionState.Listening
    is VoiceControllerState.ModelSpeaking -> CompanionState.Speaking
    is VoiceControllerState.Connecting -> CompanionState.Focused
    is VoiceControllerState.Idle, is VoiceControllerState.Error -> null
}

/**
 * الوصف المسموع لحالة الأيجنت — لقارئ الشاشة، الشكل واللون بصريين بس.
 *
 * اتحوّلت لـ stringResource وقت إضافة Listening/Speaking: دي نصوص contentDescription
 * وTalkBack بيقراها لضعاف البصر، فهي نصوص واجهة بحسب قاعدة i18n في CLAUDE.md.
 * كانت عربي ثابت؛ إضافة اتنين جداد بنفس الشكل كانت هتزوّد المخالفة مش تقفلها.
 */
@Composable
fun companionStateDescription(state: CompanionState): String = stringResource(
    when (state) {
        CompanionState.Idle -> R.string.companion_state_idle
        CompanionState.Listening -> R.string.companion_state_listening
        CompanionState.Focused -> R.string.companion_state_focused
        CompanionState.Speaking -> R.string.companion_state_speaking
        CompanionState.Happy -> R.string.companion_state_happy
        CompanionState.Alert -> R.string.companion_state_alert
        CompanionState.Celebrating -> R.string.companion_state_celebrating
    }
)

/**
 * خطوة الفلتر الأسّي للسعة — دالة نقية عشان تكون قابلة للاختبار.
 *
 * **الصعود أسرع من الهبوط بقصد:** 0.45 طالع عشان أول مقطع نطق يبان فوراً، و0.12
 * نازل عشان الكورة ماترجعش لصفر في كل سكتة بين كلمتين. لو الاتنين اتساووا، الحركة
 * بتتقري إما "بطيئة ومتأخرة" أو "مرتعشة" — والفرق ده هو كل الفرق بين كورة بتتجاوب
 * وكورة بتتنطط.
 */
internal fun smoothOrbLevel(current: Float, raw: Float): Float {
    val target = raw.coerceIn(0f, 1f)
    val factor = if (target > current) 0.45f else 0.12f
    return current + (target - current) * factor
}

/**
 * مصدر السعة الموحّد للكورة — بيجمّع الفلو بنفسه وبينعّمه.
 *
 * **بياخد الـflow مش القيمة، وده جوهر الحارس.** لو المستدعي عمل
 * `micLevel.collectAsState()` وبعت الـ`Float`، **المستدعي نفسه** كان هيعيد التركيب
 * مع كل انبعاث — والمصدر بيبعت مرة لكل بافر صوت (`ZadLiveVoiceSession.updateMicLevel`
 * جوه لوب القراءة، و`ZadVoiceManager` من `onRmsChanged`)، يعني عشرات المرات في
 * الثانية طول المكالمة. بالجمع هنا، الانبعاث بيكتب في `MutableFloatState` واللي
 * بيقراها هو **الـdraw scope بس** عن طريق اللامبدا اللي بترجع — فبيتبطّل الرسم
 * لوحده (`invalidateDraw`) ومفيش ولا recomposition واحدة من الصوت.
 *
 * **والتنعيم مش تجميل:** RMS خام بيقفز بين بافر وبافر فبيتقري "ارتعاش". فلتر أسّي
 * بصعود أسرع من الهبوط بيدي إحساس "بتتجاوب": بتلحق أول مقطع نطق فوراً، وماترجعش
 * لصفر في كل سكتة بين كلمتين.
 *
 * [levelFlow] = `null` معناها مفيش صوت شغال، فبترجع صفر والكورة تكمّل تنفسها العادي.
 */
@Composable
fun rememberOrbAudioLevel(levelFlow: kotlinx.coroutines.flow.StateFlow<Float>?): () -> Float {
    val smoothed = remember { androidx.compose.runtime.mutableFloatStateOf(0f) }
    LaunchedEffect(levelFlow) {
        if (levelFlow == null) {
            smoothed.floatValue = 0f
            return@LaunchedEffect
        }
        levelFlow.collect { raw ->
            smoothed.floatValue = smoothOrbLevel(smoothed.floatValue, raw)
        }
    }
    return remember(smoothed) { { smoothed.floatValue } }
}

/**
 * كائن زاد الأليف — أفتار الأيجنت الواحد في كل التطبيق (الرئيسية، الشات، شيت الصوت).
 *
 * اتعاد رسمه ٢٠٢٦-٠٩-١٤ على الصور المرجعية: كرة لامعة ناعمة التظليل + هالة + عيون
 * كبسولة بيضا. القديم كان فيه دوّامة ألوان رخامية وحلقات مدارية بنقط وعيون حمرا في
 * Alert — شكل "خيال علمي" مش كائن لطيف.
 *
 * [animated] بيتحكم في كل الحركة المستمرة (نبض + تموّج السائل + الرمش العشوائي). خليه true
 * بس في الأماكن البارزة (رأس الشاشة/الشات) — نسخة كل فقاعة رسالة في لستة طويلة بتتقفل
 * (animated=false) عشان مانشغلش عشرات الـ infinite animation loops مع بعض في LazyColumn.
 */
@Composable
fun CompanionOrb(
    state: CompanionState,
    modifier: Modifier = Modifier,
    size: Dp = 96.dp,
    animated: Boolean = true,
    // كل تغيير في القيمة دي (مش القيمة نفسها) بيطلق رمشتين سريعتين فوراً — استخدامها
    // الوحيد دلوقتي: FloatingMascotCompanion بيغيّرها لحظة الـ tap عشان "تعبير لطيف"
    // بدل ما ينتظر الرمشة العشوائية العادية (٢٫٢-٥ ثواني).
    blinkTrigger: Long = 0L,
    // نفس اتفاقية blinkTrigger: التغيير هو الإشارة. بيولّع هالة حوالين الكورة وبتخبي
    // في ٤٥٠ms. القفزة (tapScale) بتحرّك الحجم، ودي بتحرّك الضوء — الاتنين مع بعض
    // هما اللي بيخلوا اللمسة تحس إنها اترددت، مش اتسجلت وخلاص.
    glowTrigger: Long = 0L,
    /**
     * سعة الصوت اللحظية 0..1 — الكورة بتنبض بيها وهي بتسمع.
     *
     * **لامبدا مش `Float`، والسبب أدائي مش أسلوبي.** المصدر
     * (`ZadVoiceController` mic loop) بيحدّث القيمة **مرة لكل بافر مايك** —
     * عشرات المرات في الثانية على 16kHz mono PCM16. لو البارامتر كان `Float`،
     * كل انبعاث كان هيعمل recomposition لشجرة الكورة كلها بنفس المعدل، طول المكالمة.
     * كلامبدا، القراءة بتحصل **جوه الـdraw scope** فبتبطّل الرسم لوحده
     * (`invalidateDraw`) من غير إعادة تركيب. استخدم [rememberOrbAudioLevel] كمصدر —
     * هي كمان بتنعّم القيمة عشان الحركة تتقري "حية" مش "مرتعشة".
     *
     * الافتراضي `{ 0f }` يعني كل نقطة نداء ماتمرّرهاش بتفضل زي ما هي بالظبط.
     */
    audioLevel: () -> Float = { 0f },
    /**
     * لمسة على الكورة. بتشغّل قفزة + زقزقة + رمشتين + هالة مع بعض.
     *
     * الرمش والهالة كان ليهم آلية كاملة (`blinkTrigger`/`glowTrigger`) و**صفر نقط
     * نداء** — التعليق فوقهم كان بيشاور على `FloatingMascotCompanion` وهو مابقاش
     * موجود. البارامتر ده بيوصّلهم.
     */
    onClick: (() -> Unit)? = null
) {
    // اللمسة بتولّد نفس الإشارتين اللي البارامترات الخارجية بتولّدهم، فالمسارين
    // بيروحوا لنفس المكان ومفيش منطق متكرر.
    var tapPulse by remember { mutableStateOf(0L) }
    val effectiveBlink = if (tapPulse != 0L) tapPulse else blinkTrigger
    val effectiveGlow = if (tapPulse != 0L) tapPulse else glowTrigger

    val skyColor by animateColorAsState(state.skyColor, tween(500), label = "orbSky")
    val deepColor by animateColorAsState(state.deepColor, tween(500), label = "orbDeep")

    val breathScale: Float
    val blobPhase: Float
    val rotationAngle: Float
    val sheenProgress: Float

    if (animated) {
        val breathTransition = rememberInfiniteTransition(label = "orbBreath")
        breathScale = breathTransition.animateFloat(
            initialValue = 0.98f,
            targetValue = 1.05f,
            animationSpec = infiniteRepeatable(
                animation = tween(2600, easing = FastOutSlowInEasing),
                repeatMode = RepeatMode.Reverse
            ),
            label = "orbBreathScale"
        ).value

        val blobTransition = rememberInfiniteTransition(label = "orbBlob")
        blobPhase = blobTransition.animateFloat(
            initialValue = 0f,
            targetValue = (2 * Math.PI).toFloat(),
            animationSpec = infiniteRepeatable(
                animation = tween(6000, easing = LinearEasing)
            ),
            label = "orbBlobPhase"
        ).value

        val rotateTransition = rememberInfiniteTransition(label = "orbRotate")
        rotationAngle = rotateTransition.animateFloat(
            initialValue = 0f,
            targetValue = 360f,
            animationSpec = infiniteRepeatable(
                animation = tween(10000, easing = LinearEasing),
                repeatMode = RepeatMode.Restart
            ),
            label = "orbRotation"
        ).value

        val sheenTransition = rememberInfiniteTransition(label = "orbSheen")
        sheenProgress = sheenTransition.animateFloat(
            initialValue = 0.15f,
            targetValue = 0.55f,
            animationSpec = infiniteRepeatable(
                animation = tween(3200, easing = FastOutSlowInEasing),
                repeatMode = RepeatMode.Reverse
            ),
            label = "orbSheen"
        ).value
    } else {
        breathScale = 1f
        blobPhase = 0f
        rotationAngle = 0f
        sheenProgress = 0.3f
    }

    var eyeOpen by remember { mutableFloatStateOf(1f) }
    val eyeOpenAnimated by animateFloatAsState(
        targetValue = eyeOpen,
        animationSpec = tween(85, easing = FastOutSlowInEasing),
        label = "orbBlink"
    )

    LaunchedEffect(effectiveBlink) {
        if (effectiveBlink != 0L) {
            eyeOpen = 0.08f
            delay(90)
            eyeOpen = 1f
            delay(70)
            eyeOpen = 0.08f
            delay(90)
            eyeOpen = 1f
        }
    }

    LaunchedEffect(animated) {
        if (!animated) return@LaunchedEffect
        while (true) {
            delay(Random.nextLong(2400, 5200))
            eyeOpen = 0.08f
            delay(100)
            eyeOpen = 1f
        }
    }

    var glowTarget by remember { mutableFloatStateOf(0f) }
    val glow by animateFloatAsState(glowTarget, tween(450, easing = FastOutSlowInEasing), label = "orbGlow")
    LaunchedEffect(effectiveGlow) {
        if (effectiveGlow != 0L) {
            glowTarget = 1f
            delay(120)
            glowTarget = 0f
        }
    }

    // القفزة النابية على اللمس
    val tapScale by animateFloatAsState(
        targetValue = if (glowTarget > 0f) 0.92f else 1f,
        animationSpec = ZadSprings.Press,
        label = "orbTapScale"
    )

    val orbModifier = if (animated) {
        val description = companionStateDescription(state)
        modifier.size(size).semantics { contentDescription = description }
    } else {
        modifier.size(size)
    }
    val clickableModifier = if (onClick != null) {
        orbModifier
            .scale(tapScale)
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null
            ) {
                tapPulse = System.currentTimeMillis()
                onClick()
            }
    } else {
        orbModifier
    }

    // هزّة قصيرة لحظة الدخول في Alert — "زعلان"، مش إنذار مستمر بيزعج.
    val shake = remember { androidx.compose.animation.core.Animatable(0f) }
    LaunchedEffect(state, animated) {
        if (!animated || state != CompanionState.Alert) {
            shake.snapTo(0f)
            return@LaunchedEffect
        }
        repeat(3) {
            shake.animateTo(1f, tween(55))
            shake.animateTo(-1f, tween(55))
        }
        shake.animateTo(0f, tween(80))
    }

    Canvas(modifier = clickableModifier) {
        val level = audioLevel().coerceIn(0f, 1f)
        val canvasCenter = Offset(this.size.width / 2f, this.size.height / 2f)
        // 0.62 مش 0.68: الهالة والظل محتاجين مكان جوه نفس المقاس، وإلا بيتقصّوا عند الحافة.
        val baseRadius = (this.size.minDimension / 2f) * 0.62f
        val radius = baseRadius * breathScale * (1f + 0.08f * level)

        // ارتداد وهي بتتكلم (تتنطط مع الصوت) — وانتباه لقدّام وهي بتسمع (ميل خفيف لفوق).
        val lift = when (state) {
            CompanionState.Speaking -> -radius * 0.07f * level
            CompanionState.Listening -> -radius * 0.03f
            CompanionState.Celebrating, CompanionState.Happy -> -radius * 0.04f * sin(blobPhase * 2f)
            else -> 0f
        }
        val center = canvasCenter + Offset(shake.value * radius * 0.07f, lift)
        // squash & stretch: الكلام بيوسّع الجسم ويقصّره سنة — ده اللي بيحسّس إن الصوت طالع منها.
        val squashX = 1f + if (state == CompanionState.Speaking) 0.05f * level else 0f
        val squashY = 1f - if (state == CompanionState.Speaking) 0.04f * level else 0f

        // 1. ظل أرضي ناعم — بيقل لما الجسم يرتفع، زي جسم حقيقي فوق سطح.
        val shadowWidth = radius * 1.35f * (1f + lift / (radius * 2f))
        drawOval(
            brush = Brush.radialGradient(
                colors = listOf(deepColor.copy(alpha = 0.22f), Color.Transparent),
                center = Offset(canvasCenter.x, canvasCenter.y + radius * 1.12f),
                radius = shadowWidth / 2f
            ),
            topLeft = Offset(canvasCenter.x - shadowWidth / 2f, canvasCenter.y + radius * 1.02f),
            size = androidx.compose.ui.geometry.Size(shadowWidth, radius * 0.22f)
        )

        // 2. هالة — بتتنفس مع الصوت. شفافة فبتتركّب صح فوق اللايت والدارك.
        val haloRadius = radius * (1.42f + 0.28f * level + 0.2f * glow)
        drawCircle(
            brush = Brush.radialGradient(
                colors = listOf(
                    skyColor.copy(alpha = (0.30f + 0.30f * level + 0.25f * glow).coerceAtMost(0.85f)),
                    skyColor.copy(alpha = 0.10f),
                    Color.Transparent
                ),
                center = center,
                radius = haloRadius
            ),
            radius = haloRadius,
            center = center
        )

        withTransform({ scale(squashX, squashY, pivot = center) }) {
            // 3. الجسم: تدرّج كروي بمصدر ضوء فوق-شمال — ده اللي بيدّي إحساس الـ3D.
            drawCircle(
                brush = Brush.radialGradient(
                    colors = listOf(
                        lerp(skyColor, Color.White, 0.42f),
                        skyColor,
                        lerp(skyColor, deepColor, 0.55f),
                        deepColor
                    ),
                    center = center - Offset(radius * 0.32f, radius * 0.38f),
                    radius = radius * 1.55f
                ),
                radius = radius,
                center = center
            )

            val bodyClip = Path().apply {
                addOval(androidx.compose.ui.geometry.Rect(center, radius))
            }
            clipPath(bodyClip) {
                // 4. ضوء مرتد من تحت-يمين: بيفصل حافة الكورة عن الخلفية.
                drawCircle(
                    brush = Brush.radialGradient(
                        colors = listOf(lerp(skyColor, Color.White, 0.25f).copy(alpha = 0.45f), Color.Transparent),
                        center = center + Offset(radius * 0.42f, radius * 0.62f),
                        radius = radius * 0.62f
                    ),
                    radius = radius * 0.62f,
                    center = center + Offset(radius * 0.42f, radius * 0.62f)
                )
                // 5. لمعة التفكير: بقعة ضوء بتلف ببطء جوه الكورة.
                if (state == CompanionState.Focused) {
                    val a = rotationAngle * (Math.PI / 180.0).toFloat()
                    val swirlCenter = center + Offset(cos(a) * radius * 0.45f, sin(a) * radius * 0.45f)
                    drawCircle(
                        brush = Brush.radialGradient(
                            colors = listOf(Color.White.copy(alpha = 0.30f), Color.Transparent),
                            center = swirlCenter,
                            radius = radius * 0.7f
                        ),
                        radius = radius * 0.7f,
                        center = swirlCenter
                    )
                }
            }

            // 6. لمعة زجاجية بيضاوية فوق-شمال. (نقطة لمعان منفصلة اتجربت واتشالت: على
            // الحجم الصغير كانت بتتقري عين تالتة.)
            withTransform({ rotate(-32f, pivot = center - Offset(radius * 0.40f, radius * 0.46f)) }) {
                val specCenter = center - Offset(radius * 0.40f, radius * 0.46f)
                drawOval(
                    brush = Brush.radialGradient(
                        colors = listOf(
                            Color.White.copy(alpha = (0.62f + 0.25f * sheenProgress).coerceAtMost(0.9f)),
                            Color.White.copy(alpha = 0f)
                        ),
                        center = specCenter,
                        radius = radius * 0.34f
                    ),
                    topLeft = specCenter - Offset(radius * 0.34f, radius * 0.19f),
                    size = androidx.compose.ui.geometry.Size(radius * 0.68f, radius * 0.38f)
                )
            }

            // 7. حافة فريسنل رفيعة.
            drawCircle(
                brush = Brush.verticalGradient(
                    colors = listOf(Color.White.copy(alpha = 0.55f), Color.White.copy(alpha = 0.08f)),
                    startY = center.y - radius,
                    endY = center.y + radius
                ),
                radius = radius,
                center = center,
                style = androidx.compose.ui.graphics.drawscope.Stroke(width = 1.2.dp.toPx())
            )

            // 8. العيون.
            drawCompanionEyes(
                state = state,
                center = center,
                radius = radius,
                openAmount = eyeOpenAnimated,
                audioLevel = level,
                phase = blobPhase,
            )
        }

        // 9. احتفال: نجوم دهبي صغيرة بتلف حوالين الكورة.
        if (state == CompanionState.Celebrating) {
            for (i in 0 until 4) {
                val a = (rotationAngle + i * 90f) * (Math.PI / 180.0).toFloat()
                val starCenter = center + Offset(cos(a) * radius * 1.32f, sin(a) * radius * 1.32f)
                drawSparkle(starCenter, radius * (0.10f + 0.03f * sin(blobPhase * 3f + i)), ZadHeartYellow)
            }
        }
    }
}

/**
 * عيون الكائن: كبسولتين بيض (نفس الصور المرجعية)، والتعبير كله من الشكل والمكان مش من
 * بؤبؤ داكن — على 56dp في الرئيسية البؤبؤ كان بيبقى بقعة رمادية مش عين.
 */
private fun androidx.compose.ui.graphics.drawscope.DrawScope.drawCompanionEyes(
    state: CompanionState,
    center: Offset,
    radius: Float,
    openAmount: Float,
    audioLevel: Float,
    phase: Float,
) {
    val spacing = radius * 0.36f
    val width = radius * 0.22f
    val baseY = center.y - radius * 0.06f

    // اتجاه النظرة لكل حالة.
    val look = when (state) {
        CompanionState.Idle -> Offset(radius * 0.05f * sin(phase * 0.5f), 0f)          // بتبص حواليها
        CompanionState.Listening -> Offset(0f, -radius * 0.04f)                          // منتبهة لقدّام
        CompanionState.Focused -> Offset(radius * 0.08f * cos(phase), -radius * 0.10f) // بتفكر لفوق
        else -> Offset.Zero
    }
    val left = Offset(center.x - spacing, baseY) + look
    val right = Offset(center.x + spacing, baseY) + look

    when (state) {
        CompanionState.Happy, CompanionState.Celebrating -> {
            // ^ ^
            drawHappyArc(left, width * 1.5f, radius * 0.16f, radius * 0.085f)
            drawHappyArc(right, width * 1.5f, radius * 0.16f, radius * 0.085f)
        }
        CompanionState.Alert -> {
            val h = radius * 0.40f * openAmount
            drawAngryEye(left, width, h, innerOnRight = true)
            drawAngryEye(right, width, h, innerOnRight = false)
        }
        else -> {
            val h = when (state) {
                CompanionState.Listening -> radius * (0.46f + 0.10f * audioLevel)
                CompanionState.Speaking -> radius * (0.42f - 0.12f * audioLevel)
                CompanionState.Focused -> radius * 0.34f
                else -> radius * 0.42f
            } * openAmount
            drawCapsuleEye(left, width, h)
            drawCapsuleEye(right, width, h)
        }
    }
}

private fun androidx.compose.ui.graphics.drawscope.DrawScope.drawCapsuleEye(center: Offset, width: Float, height: Float) {
    val h = height.coerceAtLeast(width * 0.35f)
    val topLeft = Offset(center.x - width / 2f, center.y - h / 2f)
    val size = androidx.compose.ui.geometry.Size(width, h)
    val corner = androidx.compose.ui.geometry.CornerRadius(width / 2f, minOf(width / 2f, h / 2f))
    // توهّج خفيف حوالين العين — نفس لمعة العيون في الصور المرجعية.
    drawRoundRect(
        color = Color.White.copy(alpha = 0.22f),
        topLeft = topLeft - Offset(width * 0.18f, width * 0.18f),
        size = androidx.compose.ui.geometry.Size(width * 1.36f, h + width * 0.36f),
        cornerRadius = androidx.compose.ui.geometry.CornerRadius(width * 0.68f, width * 0.68f)
    )
    drawRoundRect(color = Color.White, topLeft = topLeft, size = size, cornerRadius = corner)
}

/** عين زعلانة: الكبسولة نفسها مقصوصة بجفن مايل على الناحية الداخلية (حاجب مقطّب).
 *  قص مش رسم فوقها بلون الجسم: الجسم متدرّج، فأي لون ثابت كان هيبان رقعة. */
private fun androidx.compose.ui.graphics.drawscope.DrawScope.drawAngryEye(
    center: Offset,
    width: Float,
    height: Float,
    innerOnRight: Boolean,
) {
    val top = center.y - height / 2f
    val outerX = if (innerOnRight) center.x - width * 1.2f else center.x + width * 1.2f
    val innerX = if (innerOnRight) center.x + width * 1.2f else center.x - width * 1.2f
    val belowLid = Path().apply {
        moveTo(outerX, top + height * 0.02f)
        lineTo(innerX, top + height * 0.46f)
        lineTo(innerX, center.y + height)
        lineTo(outerX, center.y + height)
        close()
    }
    clipPath(belowLid) { drawCapsuleEye(center, width, height) }
}

private fun androidx.compose.ui.graphics.drawscope.DrawScope.drawHappyArc(
    center: Offset,
    width: Float,
    height: Float,
    stroke: Float
) {
    val path = Path().apply {
        moveTo(center.x - width / 2f, center.y + height / 2f)
        quadraticTo(center.x, center.y - height, center.x + width / 2f, center.y + height / 2f)
    }
    drawPath(
        path = path,
        color = Color.White,
        style = androidx.compose.ui.graphics.drawscope.Stroke(width = stroke, cap = androidx.compose.ui.graphics.StrokeCap.Round)
    )
}

private fun androidx.compose.ui.graphics.drawscope.DrawScope.drawSparkle(center: Offset, size: Float, color: Color) {
    val path = Path().apply {
        moveTo(center.x, center.y - size)
        quadraticTo(center.x, center.y, center.x + size, center.y)
        quadraticTo(center.x, center.y, center.x, center.y + size)
        quadraticTo(center.x, center.y, center.x - size, center.y)
        quadraticTo(center.x, center.y, center.x, center.y - size)
        close()
    }
    drawPath(path, color = color)
}

private val alertToneWords = listOf("تنبيه", "تحذير", "خطر", "حذر", "تجاوزت", "نفاد", "أوشك", "قارب على النفاد")
private val happyToneWords = listOf("ممتاز", "أحسنت", "تهانينا", "مبروك", "رائع", "وفرت", "نجحت", "تحقيق هدف")

/** استنتاج حالة الأيجنت من نص رسالة الشات — مافيش استدعاء AI جديد، تصنيف كلمات مفتاحية محلي بس. */
fun companionStateForMessage(text: String): CompanionState = when {
    alertToneWords.any { text.contains(it) } -> CompanionState.Alert
    happyToneWords.any { text.contains(it) } -> CompanionState.Happy
    else -> CompanionState.Idle
}
