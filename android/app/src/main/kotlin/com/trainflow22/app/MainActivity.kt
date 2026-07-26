package com.trainflow22.app

import android.media.ToneGenerator
import android.media.AudioManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "com.trainflow22.app/audio"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "playCountdownBeep" -> {
                            playCountdownBeep()
                            result.success(null)
                        }
                        "playCompletionBeep" -> {
                            playCompletionBeep()
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("AUDIO_ERROR", e.message, null)
                }
            }
    }

    private fun playCountdownBeep() {
        val toneGenerator = ToneGenerator(AudioManager.STREAM_NOTIFICATION, 100)
        try {
            toneGenerator.startTone(ToneGenerator.TONE_CDMA_ALERT_CALL_GUARD, 150)
        } finally {
            toneGenerator.release()
        }
    }

    private fun playCompletionBeep() {
        val toneGenerator = ToneGenerator(AudioManager.STREAM_NOTIFICATION, 100)
        try {
            toneGenerator.startTone(ToneGenerator.TONE_CDMA_CONFIRM, 300)
        } finally {
            toneGenerator.release()
        }
    }
}

