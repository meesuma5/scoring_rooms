package com.example.scoring_rooms

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val channelName = "score_haptics"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
			.setMethodCallHandler { call, result ->
				if (call.method == "vibrate") {
					val duration = (call.argument<Int>("duration") ?: 40)
					val amplitude = (call.argument<Int>("amplitude") ?: 180)
					val vibrator =
						getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
					if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
						vibrator.vibrate(
							VibrationEffect.createOneShot(
								duration.toLong(),
								amplitude,
							),
						)
					} else {
						@Suppress("DEPRECATION")
						vibrator.vibrate(duration.toLong())
					}
					result.success(null)
				} else {
					result.notImplemented()
				}
			}
	}
}
