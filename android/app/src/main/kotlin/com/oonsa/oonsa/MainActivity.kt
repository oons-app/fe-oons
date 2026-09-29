package com.oons.oons

import android.media.AudioAttributes
import android.media.SoundPool
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  private var soundPool: SoundPool? = null
  private var alertSoundId: Int = 0
  private var alertLoaded: Boolean = false

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    // Block screenshots, screen recording, and app-switcher previews.
    window.setFlags(
      WindowManager.LayoutParams.FLAG_SECURE,
      WindowManager.LayoutParams.FLAG_SECURE,
    )
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    ensureSoundPool()
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "oons/alert_sound")
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "unlock" -> {
            ensureSoundPool()
            result.success(null)
          }
          "play" -> {
            playAlert()
            result.success(null)
          }
          else -> result.notImplemented()
        }
      }
  }

  private fun ensureSoundPool() {
    if (soundPool != null) return
    val attrs = AudioAttributes.Builder()
      .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
      .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
      .build()
    val pool = SoundPool.Builder()
      .setMaxStreams(1)
      .setAudioAttributes(attrs)
      .build()
    pool.setOnLoadCompleteListener { _, sampleId, status ->
      if (status == 0 && sampleId == alertSoundId) {
        alertLoaded = true
      }
    }
    alertSoundId = pool.load(this, R.raw.oons_alert, 1)
    soundPool = pool
  }

  private fun playAlert() {
    ensureSoundPool()
    if (!alertLoaded || alertSoundId == 0) return
    soundPool?.play(alertSoundId, 0.85f, 0.85f, 1, 0, 1f)
  }

  override fun onDestroy() {
    soundPool?.release()
    soundPool = null
    super.onDestroy()
  }
}
