package com.aistudio.zad.wrtqvx

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.content.Context
import android.content.Intent
import android.media.RingtoneManager
import android.net.Uri
import android.telephony.TelephonyManager
import android.util.Log
import java.util.Locale
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingRingtone: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "zad/travel")
            .setMethodCallHandler { call, result ->
                if (call.method != "detectCountry") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val networkIso = try {
                    (getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager)
                        ?.networkCountryIso?.takeIf { it.isNotBlank() }
                } catch (e: Exception) {
                    null
                }
                val code = networkIso ?: Locale.getDefault().country.takeIf { it.isNotBlank() }
                result.success(code?.uppercase(Locale.US))
            }
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
    }
}
