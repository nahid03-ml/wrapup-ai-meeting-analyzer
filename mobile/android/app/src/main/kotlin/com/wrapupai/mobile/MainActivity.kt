package com.wrapupai.mobile

import android.content.Intent
import com.wrapupai.mobile.livecapture.LiveCaptureChannels
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var liveCaptureChannels: LiveCaptureChannels? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        liveCaptureChannels = LiveCaptureChannels(
            activity = this,
            messenger = flutterEngine.dartExecutor.binaryMessenger,
        ).also { it.register() }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        liveCaptureChannels?.dispose()
        liveCaptureChannels = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (liveCaptureChannels?.onActivityResult(requestCode, resultCode, data) == true) {
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }
}
