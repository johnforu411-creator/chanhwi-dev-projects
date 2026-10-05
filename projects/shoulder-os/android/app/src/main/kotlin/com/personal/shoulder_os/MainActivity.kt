package com.personal.shoulder_os

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun getInitialRoute(): String? = intent.getStringExtra("route") ?: super.getInitialRoute()

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.getStringExtra("route")?.let { route ->
            flutterEngine?.navigationChannel?.pushRoute(route)
        }
    }
}
