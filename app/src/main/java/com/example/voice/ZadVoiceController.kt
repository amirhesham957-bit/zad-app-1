package com.example.voice

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.AudioTrack
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Base64
import android.util.Log
import com.example.BuildConfig
import com.example.data.SupabaseRepo
import io.github.jan.supabase.auth.auth
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import kotlin.math.sqrt

/**
 * ZadVoiceController — المسار الصوتي الوحيد لمكالمة زاد الحية (Gemini Live عبر relay
 * `zad-voice-live`).
 *
 * كان فيه عميلين للمكالمة نفسها: ده (بيشغّله الشيت) و`ZadLiveVoiceSession` (الكورة
 * كانت بتقرا حالته، ومحدش بيشغّله). النتيجة: الكورة عمرها ما اتفاعلت مع مكالمة شغالة.
 * اتشال التاني (٢٠٢٦-٠٩-١٤) — كل حاجة بتقرا من هنا.
 *
 * 1. ميكروفون 16kHz mono PCM → `realtimeInput.audio` → Gemini Live.
 * 2. صوت الرد (24kHz PCM base64) → طابور → خيط تشغيل مستقل → AudioTrack.
 * 3. المقاطعة (barge-in): المايك مابيتكتمش وزاد بيتكلم. كان بيتكتم، فالمقاطعة كانت
 *    مستحيلة بالتصميم. دلوقتي الكلام العالي كفاية بيعدّي ([shouldForwardMic])، والـVAD
 *    بتاع جيميناي بيبعت `interrupted` فالطابور بيتفضى فورًا.
 * 4. التشغيل على خيط لوحده: كان `AudioTrack.write(BLOCKING)` على خيط قراءة OkHttp،
 *    فرسالة `interrupted` نفسها كانت بتستنى لحد ما الصوت اللي قبلها يخلص.
 */
sealed class VoiceControllerState {
    object Idle : VoiceControllerState()
    object Connecting : VoiceControllerState()
    object Listening : VoiceControllerState()
    object ModelSpeaking : VoiceControllerState()

    /** [canFallBack]: هل ينفع الشيت يكمّل بالمسار دور-بدور (تعرّف كلام + شات + صوت سارة)؟
     *  لأ لما السبب نفسه هيوقف البديل كمان (مفيش جلسة، مفيش إذن مايك). */
    data class Error(val message: String, val canFallBack: Boolean = true) : VoiceControllerState()
}

object ZadVoiceController {
    private var appContext: Context? = null

    fun init(context: Context) {
        if (appContext == null) appContext = context.applicationContext
    }

    private val context: Context
        get() = appContext ?: error("ZadVoiceController.init(context) must be called first")

    private val tag = "ZadVoiceController"
    private val mainHandler = Handler(Looper.getMainLooper())

    // object مش class: release() بيلغي الـscope، فلازم يتعمل من جديد عند أول استخدام بعدها،
    // وإلا كل فتحة للشيت بعد أول release تبقى صامتة للأبد (VoiceControllerLifecycleTest).
    @Volatile private var _scope: CoroutineScope? = null
    internal val scope: CoroutineScope
        get() = synchronized(this) {
            _scope?.takeIf { it.coroutineContext[Job]?.isActive == true }
                ?: CoroutineScope(SupervisorJob() + Dispatchers.IO).also { _scope = it }
        }

    private val _state = MutableStateFlow<VoiceControllerState>(VoiceControllerState.Idle)
    val state: StateFlow<VoiceControllerState> = _state.asStateFlow()

    /** مستوى صوت المايك (0..1) — للكورة وهي بتسمع. */
    private val _micLevel = MutableStateFlow(0f)
    val micLevel: StateFlow<Float> = _micLevel.asStateFlow()

    /** مستوى صوت رد زاد (0..1) — للكورة وهي بتتكلم. */
    private val _outputLevel = MutableStateFlow(0f)
    val outputLevel: StateFlow<Float> = _outputLevel.asStateFlow()

    private val wsClient = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(0, TimeUnit.MILLISECONDS)
        .pingInterval(20, TimeUnit.SECONDS)
        .build()

    private var webSocket: WebSocket? = null
    @Volatile private var audioRecord: AudioRecord? = null
    @Volatile private var audioTrack: AudioTrack? = null
    private var echoCanceler: android.media.audiofx.AcousticEchoCanceler? = null
    private var noiseSuppressor: android.media.audiofx.NoiseSuppressor? = null

    private val sessionActive = AtomicBoolean(false)
    private val recordingActive = AtomicBoolean(false)
    private var audioFocusRequest: AudioFocusRequest? = null

    private val inputSampleRate = 16_000
    private val outputSampleRate = 24_000

    /** كل مقاطعة بتزوّده — أي chunk من جيل قديم لسه في الطابور بيترمي من غير تشغيل. */
    private val playbackGeneration = AtomicLong(0L)
    private class PlaybackChunk(val generation: Long, val pcm: ByteArray)
    private val playbackQueue = LinkedBlockingQueue<PlaybackChunk>()
    @Volatile private var playbackThread: Thread? = null
    @Volatile private var turnCompletePending = false

    private val audioManager get() =
        context.applicationContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    private fun hasMicPermission(): Boolean =
        androidx.core.content.ContextCompat.checkSelfPermission(
            context, android.Manifest.permission.RECORD_AUDIO
        ) == android.content.pm.PackageManager.PERMISSION_GRANTED

    /**
     * يبدأ المكالمة. [personaId] = `ZadNaturalVoiceEngine.VoicePersona.id` — السيرفر
     * بيحوّله لنفس صوت جيميناي اللي قراءة الإشعارات بتستخدمه (سارة = Aoede)، فالشخصية
     * المختارة في الإعدادات بقت بتسري على المكالمة الحية كمان مش على قراءة النصوص بس.
     */
    fun start(personaId: String? = null, onError: (String) -> Unit = {}) {
        if (!hasMicPermission()) {
            _state.value = VoiceControllerState.Error("محتاج إذن الميكروفون", canFallBack = false)
            onError("permission")
            return
        }
        if (sessionActive.getAndSet(true)) return

        _state.value = VoiceControllerState.Connecting
        playbackGeneration.incrementAndGet()
        playbackQueue.clear()
        turnCompletePending = false

        try {
            audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
            audioManager.isSpeakerphoneOn = true
        } catch (e: Exception) {
            Log.w(tag, "AudioManager mode error: ${e.message}")
        }
        requestAudioFocus()

        try {
            audioTrack = buildPlaybackTrack().also { it.play() }
        } catch (e: Exception) {
            Log.w(tag, "Early AudioTrack play error: ${e.message}")
        }
        startPlaybackThread()

        scope.launch { connect(personaId, onError) }
    }

    private fun connect(personaId: String?, onError: (String) -> Unit) {
        // الهوية من JWT المستخدم بس. كان فيه fallback على الـanon key + هيدر x-user-id،
        // والسيرفر كان بيصدّقه وينفّذ أدوات باسم أي حساب — اتقفل من الناحيتين (٢٠٢٦-٠٩-١٤).
        val token = SupabaseRepo.client.auth.currentSessionOrNull()?.accessToken?.takeIf { it.isNotBlank() }
        if (token == null) {
            failSession(liveVoiceCloseMessage(LIVE_CLOSE_UNAUTHORIZED, "") ?: "محتاج تسجّل دخول", canFallBack = false)
            onError("no_session")
            return
        }

        val baseUrl = if (BuildConfig.SUPABASE_URL.isNotBlank() && !BuildConfig.SUPABASE_URL.contains("your-project-ref")) {
            BuildConfig.SUPABASE_URL
        } else {
            "https://auuftqncrjsnyylolhbu.supabase.co"
        }
        // OkHttp بيحوّل https→wss بنفسه في newWebSocket؛ الـHttpUrl builder بيضمن encoding الباراميتر.
        val url = (baseUrl.trimEnd('/') + "/functions/v1/zad-voice-live").toHttpUrlOrNull()
            ?.newBuilder()
            ?.apply { if (!personaId.isNullOrBlank()) addQueryParameter("voice", personaId) }
            ?.build()
        if (url == null) {
            failSession("تعذّر الاتصال بالمساعد الصوتي")
            onError("bad_url")
            return
        }

        val apiKey = BuildConfig.SUPABASE_ANON_KEY.ifBlank { SupabaseRepo.client.supabaseKey }
        val request = Request.Builder()
            .url(url)
            .addHeader("Authorization", "Bearer $token")
            .addHeader("apikey", apiKey)
            .build()

        webSocket = wsClient.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                Log.d(tag, "zad-voice-live connected")
                startMicStreaming(webSocket)
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                handleServerFrame(text)
            }

            // السيرفر بيحوّل الفريمات لنص، بس نسخة سيرفر أقدم أو وسيط ممكن يعدّي بايتات —
            // من غير الـoverride ده OkHttp بيرميها بصمت، والصوت بيختفي من غير أي خطأ.
            override fun onMessage(webSocket: WebSocket, bytes: okio.ByteString) {
                handleServerFrame(bytes.utf8())
            }

            override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
                webSocket.close(1000, null)
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                Log.d(tag, "zad-voice-live closed: $code $reason")
                val message = liveVoiceCloseMessage(code, reason)
                if (message != null && this@ZadVoiceController.webSocket === webSocket) {
                    // رفض أو انقطاع من المزوّد: الحالة لازم تقول السبب، مش ترجع Idle ساكتة.
                    Log.w(tag, "zad-voice-live rejected/ended: $code $reason")
                    failSession(message, canFallBack = code != LIVE_CLOSE_UNAUTHORIZED)
                } else {
                    teardown(toIdle = true)
                }
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                Log.w(tag, "zad-voice-live failure: ${t.message} (http=${response?.code})")
                if (this@ZadVoiceController.webSocket !== webSocket) return
                val unauthorized = response?.code == 401
                failSession(
                    if (unauthorized) "محتاج تسجّل دخول تاني" else "تعذّر الاتصال بالمساعد الصوتي",
                    canFallBack = !unauthorized
                )
                onError("ws_failure:${response?.code}")
            }
        })
    }

    /**
     * يبعت نص (سؤال جاهز من الشيت) جوه نفس المكالمة — الرد بيجي بنفس الصوت الحي بدل ما
     * الأسئلة الجاهزة تبقى متاحة في المسار القديم بس. false لو مفيش مكالمة متصلة.
     */
    fun sendText(text: String): Boolean {
        val ws = webSocket ?: return false
        val current = _state.value
        if (!sessionActive.get() || (current != VoiceControllerState.Listening && current != VoiceControllerState.ModelSpeaking)) {
            return false
        }
        val frame = JSONObject().put(
            "clientContent",
            JSONObject()
                .put("turns", JSONArray().put(
                    JSONObject().put("role", "user").put("parts", JSONArray().put(JSONObject().put("text", text)))
                ))
                .put("turnComplete", true)
        )
        return try {
            ws.send(frame.toString())
        } catch (e: Exception) {
            Log.w(tag, "send text failed: ${e.message}")
            false
        }
    }

    private fun startMicStreaming(connectedSocket: WebSocket) {
        if (webSocket !== connectedSocket || !sessionActive.get()) {
            Log.w(tag, "Cannot start mic streaming: connection not ready")
            return
        }
        if (recordingActive.getAndSet(true)) return

        scope.launch {
            val minBuf = AudioRecord.getMinBufferSize(
                inputSampleRate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT
            ).coerceAtLeast(inputSampleRate / 2)

            var record: AudioRecord? = null
            try {
                record = AudioRecord(
                    MediaRecorder.AudioSource.VOICE_COMMUNICATION,
                    inputSampleRate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, minBuf * 2
                )
            } catch (e: SecurityException) {
                Log.w(tag, "AudioRecord init denied: ${e.message}")
                recordingActive.set(false)
                failSession("محتاج إذن الميكروفون", canFallBack = false)
                return@launch
            } catch (e: Exception) {
                Log.w(tag, "AudioRecord VOICE_COMMUNICATION failed: ${e.message}, trying MIC fallback")
            }

            if (record == null || record.state != AudioRecord.STATE_INITIALIZED) {
                try { record?.release() } catch (_: Exception) {}
                try {
                    record = AudioRecord(
                        MediaRecorder.AudioSource.MIC,
                        inputSampleRate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, minBuf * 2
                    )
                } catch (e: Exception) {
                    Log.w(tag, "AudioRecord MIC fallback failed: ${e.message}")
                }
            }

            if (record == null || record.state != AudioRecord.STATE_INITIALIZED) {
                Log.w(tag, "AudioRecord not initialized, state=${record?.state}")
                try { record?.release() } catch (_: Exception) {}
                recordingActive.set(false)
                failSession("تعذّر تجهيز الميكروفون", canFallBack = false)
                return@launch
            }
            audioRecord = record

            if (!sessionActive.get() || webSocket !== connectedSocket) {
                try { record.release() } catch (_: Exception) {}
                if (audioRecord === record) audioRecord = null
                recordingActive.set(false)
                return@launch
            }

            // AEC هو اللي بيخلّي المايك المفتوح وقت كلام زاد ممكن من غير ما يسمع نفسه.
            val sessionId = record.audioSessionId
            if (sessionId != 0) {
                if (android.media.audiofx.AcousticEchoCanceler.isAvailable()) {
                    try {
                        echoCanceler = android.media.audiofx.AcousticEchoCanceler.create(sessionId)?.apply { enabled = true }
                    } catch (e: Exception) {
                        Log.w(tag, "AEC enable failed: ${e.message}")
                    }
                }
                if (android.media.audiofx.NoiseSuppressor.isAvailable()) {
                    try {
                        noiseSuppressor = android.media.audiofx.NoiseSuppressor.create(sessionId)?.apply { enabled = true }
                    } catch (e: Exception) {
                        Log.w(tag, "NoiseSuppressor enable failed: ${e.message}")
                    }
                }
            }

            val buffer = ByteArray(minBuf)
            try {
                record.startRecording()
                if (record.recordingState != AudioRecord.RECORDSTATE_RECORDING) {
                    Log.w(tag, "AudioRecord failed to start recording: ${record.recordingState}")
                    recordingActive.set(false)
                    failSession("تعذّر بدء التقاط الصوت", canFallBack = false)
                    return@launch
                }
                mainHandler.post {
                    if (sessionActive.get() && webSocket === connectedSocket) {
                        _state.value = VoiceControllerState.Listening
                    }
                }

                while (sessionActive.get() && recordingActive.get() && webSocket === connectedSocket) {
                    val read = record.read(buffer, 0, buffer.size)
                    if (read <= 0) {
                        if (read < 0) kotlinx.coroutines.delay(10)
                        continue
                    }
                    val chunk = if (read == buffer.size) buffer else buffer.copyOf(read)
                    val level = pcmLevel(chunk)
                    _micLevel.value = level
                    if (shouldForwardMic(_state.value == VoiceControllerState.ModelSpeaking, level)) {
                        sendAudioChunk(connectedSocket, chunk)
                    }
                }
            } catch (e: Exception) {
                Log.w(tag, "mic loop failed: ${e.message}")
            } finally {
                try { echoCanceler?.release() } catch (_: Exception) {}
                echoCanceler = null
                try { noiseSuppressor?.release() } catch (_: Exception) {}
                noiseSuppressor = null
                try { record.stop() } catch (_: Exception) {}
                try { record.release() } catch (_: Exception) {}
                if (audioRecord === record) audioRecord = null
                recordingActive.set(false)
            }
        }
    }

    private fun sendAudioChunk(ws: WebSocket, pcm: ByteArray) {
        if (!sessionActive.get() || webSocket !== ws) return
        // `realtimeInput.audio` هو الحقل الحالي؛ `mediaChunks` مهجور في Live API.
        val frame = JSONObject().put(
            "realtimeInput",
            JSONObject().put(
                "audio",
                JSONObject()
                    .put("mimeType", "audio/pcm;rate=$inputSampleRate")
                    .put("data", Base64.encodeToString(pcm, Base64.NO_WRAP))
            )
        )
        try {
            ws.send(frame.toString())
        } catch (e: Exception) {
            Log.w(tag, "send audio chunk failed: ${e.message}")
        }
    }

    private fun handleServerFrame(text: String) {
        try {
            val json = JSONObject(text)
            val serverContent = json.optJSONObject("serverContent") ?: return

            if (serverContent.optBoolean("interrupted", false)) {
                interruptPlayback()
                return
            }

            val parts = serverContent.optJSONObject("modelTurn")?.optJSONArray("parts")
                ?: serverContent.optJSONArray("parts")
            if (parts != null) {
                val generation = playbackGeneration.get()
                for (i in 0 until parts.length()) {
                    val data = parts.optJSONObject(i)?.optJSONObject("inlineData")?.optString("data", "").orEmpty()
                    if (data.isNotEmpty()) {
                        playbackQueue.offer(PlaybackChunk(generation, Base64.decode(data, Base64.DEFAULT)))
                    }
                }
            }

            // الدور خلص من ناحية جيميناي، بس الصوت ممكن لسه في الطابور — خيط التشغيل هو
            // اللي بيرجّع الحالة لـListening لما الطابور يفضى فعلاً.
            if (serverContent.optBoolean("turnComplete", false)) {
                turnCompletePending = true
            }
        } catch (e: Exception) {
            Log.w(tag, "failed to parse server frame: ${e.message}")
        }
    }

    private fun startPlaybackThread() {
        if (playbackThread?.isAlive == true) return
        // كل خيط بيخرج أول ما مايبقاش هو الحالي: إعادة تشغيل سريعة ممكن تلاقي الخيط القديم
        // لسه جوه write()، ومن غير الشرط ده خيطين كانوا هيكتبوا على نفس الـAudioTrack.
        val thread = Thread({
            while (sessionActive.get() && playbackThread === Thread.currentThread()) {
                val chunk = try {
                    playbackQueue.poll(120, TimeUnit.MILLISECONDS)
                } catch (_: InterruptedException) {
                    break
                }
                if (chunk == null) {
                    _outputLevel.value = 0f
                    if (turnCompletePending) {
                        turnCompletePending = false
                        mainHandler.post {
                            if (sessionActive.get() && _state.value == VoiceControllerState.ModelSpeaking) {
                                _state.value = VoiceControllerState.Listening
                            }
                        }
                    }
                    continue
                }
                if (chunk.generation != playbackGeneration.get()) continue
                if (_state.value != VoiceControllerState.ModelSpeaking) {
                    mainHandler.post {
                        if (sessionActive.get() && chunk.generation == playbackGeneration.get()) {
                            _state.value = VoiceControllerState.ModelSpeaking
                        }
                    }
                }
                _outputLevel.value = pcmLevel(chunk.pcm)
                val track = audioTrack ?: continue
                try {
                    if (track.playState != AudioTrack.PLAYSTATE_PLAYING) track.play()
                    track.write(chunk.pcm, 0, chunk.pcm.size, AudioTrack.WRITE_BLOCKING)
                } catch (e: Exception) {
                    Log.w(tag, "playback write failed: ${e.message}")
                }
            }
            _outputLevel.value = 0f
        }, "zad-voice-playback").apply { isDaemon = true }
        playbackThread = thread
        thread.start()
    }

    /** المستخدم اتكلم فوق زاد: الصوت اللي في الطابور بيترمي فورًا والكورة ترجع تسمع. */
    private fun interruptPlayback() {
        playbackGeneration.incrementAndGet()
        playbackQueue.clear()
        turnCompletePending = false
        try {
            audioTrack?.let { it.pause(); it.flush(); it.play() }
        } catch (_: Exception) {}
        _outputLevel.value = 0f
        mainHandler.post { if (sessionActive.get()) _state.value = VoiceControllerState.Listening }
    }

    private fun buildPlaybackTrack(): AudioTrack {
        val minBufferSize = AudioTrack.getMinBufferSize(
            outputSampleRate, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT
        ).coerceAtLeast(outputSampleRate / 2)
        return AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(outputSampleRate)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build()
            )
            .setBufferSizeInBytes(minBufferSize * 2)
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()
    }

    private fun requestAudioFocus(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build()
                )
                .setOnAudioFocusChangeListener { }
                .build()
            audioFocusRequest = request
            return audioManager.requestAudioFocus(request) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        }
        @Suppress("DEPRECATION")
        return audioManager.requestAudioFocus(null, AudioManager.STREAM_VOICE_CALL, AudioManager.AUDIOFOCUS_GAIN) ==
            AudioManager.AUDIOFOCUS_REQUEST_GRANTED
    }

    private fun abandonAudioFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioFocusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
        } else {
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(null)
        }
        audioFocusRequest = null
    }

    /** يقفل المكالمة بالكامل (قفل الشيت، زرار الإيقاف). */
    fun stop() {
        if (!sessionActive.getAndSet(false)) return
        recordingActive.set(false)
        try { webSocket?.close(1000, "client stop") } catch (_: Exception) {}
        webSocket = null
        teardown(toIdle = true)
    }

    private fun failSession(message: String, canFallBack: Boolean = true) {
        sessionActive.set(false)
        try { webSocket?.close(1000, "session failed") } catch (_: Exception) {}
        webSocket = null
        teardown(toIdle = false)
        mainHandler.post { _state.value = VoiceControllerState.Error(message, canFallBack) }
    }

    private fun teardown(toIdle: Boolean) {
        sessionActive.set(false)
        recordingActive.set(false)
        playbackGeneration.incrementAndGet()
        playbackQueue.clear()
        turnCompletePending = false
        playbackThread?.interrupt()
        playbackThread = null

        try { echoCanceler?.release() } catch (_: Exception) {}
        echoCanceler = null
        try { noiseSuppressor?.release() } catch (_: Exception) {}
        noiseSuppressor = null
        try { audioRecord?.stop() } catch (_: Exception) {}
        try { audioRecord?.release() } catch (_: Exception) {}
        audioRecord = null

        val track = audioTrack
        audioTrack = null
        try {
            track?.pause(); track?.flush(); track?.stop(); track?.release()
        } catch (_: Exception) {}

        abandonAudioFocus()
        try {
            audioManager.mode = AudioManager.MODE_NORMAL
            audioManager.isSpeakerphoneOn = false
        } catch (_: Exception) {}

        _micLevel.value = 0f
        _outputLevel.value = 0f
        if (toIdle) {
            mainHandler.post {
                if (_state.value !is VoiceControllerState.Error) _state.value = VoiceControllerState.Idle
            }
        }
    }

    /** يرجّع الحالة لـIdle بعد خطأ اتعرض (مثلاً قبل إعادة المحاولة أو التحويل للبديل). */
    fun clearError() {
        if (_state.value is VoiceControllerState.Error) _state.value = VoiceControllerState.Idle
    }

    fun release() {
        stop()
        synchronized(this) {
            _scope?.cancel()
            _scope = null
        }
    }
}

/**
 * مستوى الكلام اللي لازم يعدّي وزاد بيتكلم عشان يتحسب مقاطعة. تحته = غالبًا صدى صوت زاد
 * نفسه اللي الـAEC ماشالهوش بالكامل (سماعة خارجية)، ولو اتبعت جيميناي هيقاطع نفسه.
 * على مقياس [pcmLevel]: 0.25 ≈ RMS ‑24 dBFS — كلام عادي قريب من الموبايل بيعدّيه بسهولة،
 * وصدى بعد AEC عادةً أوطى بكتير. قيمة تجريبية: لو المقاطعة صعبة على جهاز حقيقي، ده الرقم.
 */
internal const val BARGE_IN_LEVEL = 0.25f

/** وزاد ساكت كل الصوت بيتبعت (الـVAD بتاع جيميناي بيقرر). وهو بيتكلم: الكلام الواضح بس. */
internal fun shouldForwardMic(modelSpeaking: Boolean, level: Float): Boolean =
    !modelSpeaking || level >= BARGE_IN_LEVEL

/** RMS لـPCM 16-bit little-endian، متكبّر ×4 ومقصوص على 0..1 — نفس مقياس الكورة القديم. */
internal fun pcmLevel(pcm: ByteArray): Float {
    if (pcm.size < 2) return 0f
    var sumSquares = 0.0
    var samples = 0
    var i = 0
    while (i + 1 < pcm.size) {
        val sample = ((pcm[i + 1].toInt() shl 8) or (pcm[i].toInt() and 0xFF)).toShort()
        sumSquares += (sample * sample).toDouble()
        samples++
        i += 2
    }
    if (samples == 0) return 0f
    val rms = sqrt(sumSquares / samples) / Short.MAX_VALUE
    return (rms * 4.0).coerceIn(0.0, 1.0).toFloat()
}

/** أكواد الإغلاق التطبيقية من `zad-voice-live/protocol.ts` — نفس الأرقام بالحرف. */
internal const val LIVE_CLOSE_UNAUTHORIZED = 4401
internal const val LIVE_CLOSE_ENTITLEMENT = 4402
internal const val LIVE_CLOSE_UPSTREAM_ENDED = 4502
internal const val LIVE_CLOSE_PROVIDER_UNAVAILABLE = 4503

/**
 * رسالة للمستخدم لكل إغلاق مش طبيعي، أو null لو المكالمة خلصت عادي (1000/1001).
 *
 * قبل كده أي رفض من السيرفر كان بيوصل "تعذّر الاتصال" بس — والسبب الحقيقي اللي
 * وقّف المساعد على جهاز حقيقي (رصيد صوت = صفر) ماكانش ليه أي أثر لا في التطبيق ولا
 * في اللوج. الفرز هنا هو اللي بيخلّي كل سبب يبان باسمه.
 */
internal fun liveVoiceCloseMessage(code: Int, reason: String): String? = when (code) {
    1000, 1001 -> null
    LIVE_CLOSE_UNAUTHORIZED -> "محتاج تسجّل دخول تاني عشان تكلم زاد"
    LIVE_CLOSE_ENTITLEMENT -> "خلص رصيدك من المكالمات الصوتية"
    LIVE_CLOSE_PROVIDER_UNAVAILABLE -> "الخدمة الصوتية مش متاحة دلوقتي، جرّب تاني بعد شوية"
    LIVE_CLOSE_UPSTREAM_ENDED ->
        if (reason.contains("quota", ignoreCase = true) || reason.contains("exhausted", ignoreCase = true)) {
            "زاد عليه ضغط كبير دلوقتي، جرّب تاني بعد دقيقة"
        } else {
            "المكالمة وقفت من عند الخدمة الصوتية، اضغط المايك تاني"
        }
    else -> "انقطع الاتصال بالمساعد الصوتي، اضغط المايك تاني"
}
