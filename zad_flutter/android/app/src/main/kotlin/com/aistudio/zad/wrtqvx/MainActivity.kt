package com.aistudio.zad.wrtqvx

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.content.Context
import android.content.Intent
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import android.telephony.TelephonyManager
import android.util.Log
import java.util.Locale
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var pendingRingtone: MethodChannel.Result? = null
    private var shareChannel: MethodChannel? = null
    private var pendingShare: Map<String, Any?>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // «شارك لزاد» (lib/app/share/share_intake.dart): Dart takes the share
        // when the shell is up, and is told "shared" when one arrives while it
        // runs. A share waiting for sign-in stays here until it is taken.
        shareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "zad/share")
            .also { channel ->
                channel.setMethodCallHandler { call, result ->
                    if (call.method != "take") {
                        result.notImplemented()
                        return@setMethodCallHandler
                    }
                    result.success(pendingShare)
                    pendingShare = null
                }
            }
        readShare(intent)
        // Kotlin's AssistantAlertsScreen «صوت الإشعارات»: the system's own
        // notification-sound picker, and the picked sound's display title.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "zad/ringtone")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pick" -> {
                        val existing = call.argument<String>("existing")?.let(Uri::parse)
                            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                        val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
                            putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_NOTIFICATION)
                            putExtra(RingtoneManager.EXTRA_RINGTONE_TITLE, call.argument<String>("title"))
                            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, true)
                            putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, existing)
                        }
                        pendingRingtone?.success(mapOf("cancelled" to true))
                        pendingRingtone = result
                        @Suppress("DEPRECATION")
                        startActivityForResult(intent, RINGTONE_REQUEST)
                    }
                    "title" -> {
                        val uri = call.argument<String>("uri")?.let(Uri::parse)
                            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                        val title = try {
                            RingtoneManager.getRingtone(this, uri)?.getTitle(this)
                        } catch (e: Exception) {
                            null
                        }
                        result.success(title)
                    }
                    else -> result.notImplemented()
                }
            }
        // The companion's sounds (lib/features/orb/application/pet_sound.dart):
        // Dart synthesises the PCM, this plays it exactly the way the Kotlin
        // app's ZadCutePetSoundFx does — a static AudioTrack on a daemon thread,
        // released once the clip has had time to finish.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "zad/pet_sound")
            .setMethodCallHandler { call, result ->
                if (call.method != "play") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val pcm = call.argument<ByteArray>("pcm")
                val sampleRate = call.argument<Int>("sampleRate") ?: 44100
                if (pcm == null || pcm.isEmpty()) {
                    result.success(null)
                    return@setMethodCallHandler
                }
                playPcm(pcm, sampleRate)
                result.success(null)
            }
        // Back on the home screen hides the app instead of finishing the
        // activity: finishing threw the Flutter engine away, so every return
        // went through the splash again (owner, 2026-09-29).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "zad/app")
            .setMethodCallHandler { call, result ->
                if (call.method != "background") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                result.success(moveTaskToBack(true))
            }
        // Kotlin's TravelDetector.detectCurrentCountryCode: the network's
        // country (right while roaming, unlike the SIM's), else the locale's.
        // networkCountry is the network's country alone, or null (Wi-Fi only, no
        // SIM): the trip zad-brain is told about (docs/agent/ZAD_LIVING_BRAIN.md
        // slice 6) must not come from a phone set to English (US) in Cairo.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "zad/travel")
            .setMethodCallHandler { call, result ->
                if (call.method != "detectCountry" && call.method != "networkCountry") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val networkIso = try {
                    (getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager)
                        ?.networkCountryIso?.takeIf { it.isNotBlank() }
                } catch (e: Exception) {
                    null
                }
                val code = if (call.method == "networkCountry") {
                    networkIso
                } else {
                    networkIso ?: Locale.getDefault().country.takeIf { it.isNotBlank() }
                }
                result.success(code?.uppercase(Locale.US))
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        readShare(intent)
    }

    /**
     * An ACTION_SEND from another app: its text as is, or its file copied into
     * the cache — the content URI's read grant is not meant to outlive the
     * share, and Dart reads a path. Copied off the main thread; marked so a
     * recreated activity does not take the same share twice.
     */
    private fun readShare(intent: Intent?) {
        if (intent?.action != Intent.ACTION_SEND || intent.getBooleanExtra(SHARE_TAKEN, false)) return
        intent.putExtra(SHARE_TAKEN, true)
        val stream: Uri? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }
        if (stream == null) {
            val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()?.trim()
            if (!text.isNullOrEmpty()) deliverShare(mapOf("text" to text.take(MAX_SHARED_TEXT)))
            return
        }
        val mime = intent.type
        Thread {
            val item = copyShared(stream, mime)
            runOnUiThread { deliverShare(item) }
        }.apply { isDaemon = true }.start()
    }

    private fun deliverShare(item: Map<String, Any?>) {
        pendingShare = item
        shareChannel?.invokeMethod("shared", null)
    }

    private fun copyShared(uri: Uri, mime: String?): Map<String, Any?> = try {
        var name: String? = null
        var size = -1L
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null)
            ?.use { c ->
                if (c.moveToFirst()) {
                    val n = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    val s = c.getColumnIndex(OpenableColumns.SIZE)
                    if (n >= 0 && !c.isNull(n)) name = c.getString(n)
                    if (s >= 0 && !c.isNull(s)) size = c.getLong(s)
                }
            }
        val safeName = (name ?: "shared").replace(Regex("[/\\\\:]"), "_").take(100)
        if (size > MAX_SHARED_BYTES) {
            mapOf("tooLarge" to true, "name" to safeName, "mime" to mime)
        } else {
            val dir = File(cacheDir, "shared").apply {
                deleteRecursively()
                mkdirs()
            }
            val target = File(dir, safeName)
            var copied = 0L
            val input = contentResolver.openInputStream(uri) ?: throw IllegalStateException("no stream")
            input.use { inp ->
                target.outputStream().use { out ->
                    val buf = ByteArray(64 * 1024)
                    while (true) {
                        val n = inp.read(buf)
                        if (n < 0) break
                        copied += n
                        if (copied > MAX_SHARED_BYTES) break
                        out.write(buf, 0, n)
                    }
                }
            }
            if (copied > MAX_SHARED_BYTES) {
                target.delete()
                mapOf("tooLarge" to true, "name" to safeName, "mime" to mime)
            } else {
                mapOf("path" to target.absolutePath, "name" to safeName, "mime" to mime)
            }
        }
    } catch (e: Exception) {
        Log.w("ZadShare", "could not copy the share: ${e.message}")
        mapOf("failed" to true)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != RINGTONE_REQUEST) return
        val result = pendingRingtone ?: return
        pendingRingtone = null
        if (resultCode != RESULT_OK) {
            result.success(mapOf("cancelled" to true))
            return
        }
        @Suppress("DEPRECATION")
        val picked = data?.getParcelableExtra<Uri>(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
        result.success(mapOf("cancelled" to false, "uri" to picked?.toString()))
    }

    private fun playPcm(pcm: ByteArray, sampleRate: Int) {
        Thread {
            var track: AudioTrack? = null
            try {
                track = AudioTrack.Builder()
                    .setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                    )
                    .setAudioFormat(
                        AudioFormat.Builder()
                            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                            .setSampleRate(sampleRate)
                            .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                            .build()
                    )
                    .setBufferSizeInBytes(
                        maxOf(
                            pcm.size,
                            AudioTrack.getMinBufferSize(
                                sampleRate,
                                AudioFormat.CHANNEL_OUT_MONO,
                                AudioFormat.ENCODING_PCM_16BIT
                            )
                        )
                    )
                    .setTransferMode(AudioTrack.MODE_STATIC)
                    .build()
                track.write(pcm, 0, pcm.size)
                track.play()
                Thread.sleep((pcm.size / 2) * 1000L / sampleRate + 80)
            } catch (e: Exception) {
                Log.w("ZadPetSound", "play failed: ${e.message}")
            } finally {
                try {
                    track?.release()
                } catch (_: Exception) {
                }
            }
        }.apply { isDaemon = true }.start()
    }

    private companion object {
        const val RINGTONE_REQUEST = 4711
        const val SHARE_TAKEN = "zad_share_taken"
        const val MAX_SHARED_TEXT = 4000
        // The statement import's own cap (statement_import_screen.dart).
        const val MAX_SHARED_BYTES = 10L * 1024 * 1024
    }
}
