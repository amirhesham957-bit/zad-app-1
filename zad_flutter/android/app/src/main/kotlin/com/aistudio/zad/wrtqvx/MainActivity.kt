package com.aistudio.zad.wrtqvx

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
}
