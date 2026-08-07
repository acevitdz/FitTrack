package com.cse441.fittrack

import android.content.Intent
import android.provider.Settings
import android.speech.tts.TextToSpeech
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    private var textToSpeech: TextToSpeech? = null
    private var textToSpeechReady = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        textToSpeech = TextToSpeech(this) { status ->
            textToSpeechReady = status == TextToSpeech.SUCCESS
            if (textToSpeechReady) {
                textToSpeech?.language = Locale.forLanguageTag("vi-VN")
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "fittrack/settings",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getTimeZone" -> result.success(TimeZone.getDefault().id)
                "openNotificationSettings" -> {
                    val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                        putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    }
                    startActivity(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "fittrack/tts",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> result.success(textToSpeechReady)
                "speak" -> {
                    if (!textToSpeechReady) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    val text = call.argument<String>("text").orEmpty()
                    val language = call.argument<String>("language") ?: "vi-VN"
                    val rate = (call.argument<Double>("rate") ?: 0.48).toFloat()
                    textToSpeech?.language = Locale.forLanguageTag(language)
                    textToSpeech?.setSpeechRate(rate)
                    val status = textToSpeech?.speak(
                        text,
                        TextToSpeech.QUEUE_FLUSH,
                        null,
                        "fittrack-cue",
                    )
                    result.success(status != TextToSpeech.ERROR)
                }
                "stop" -> {
                    textToSpeech?.stop()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        textToSpeech?.stop()
        textToSpeech?.shutdown()
        textToSpeech = null
        super.onDestroy()
    }
}
