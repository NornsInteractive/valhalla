package com.antigravity.valhalla.valhalla

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

object DiagnosticsChannel {
    fun register(context: Context, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "valhalla/diagnostics")
            .setMethodCallHandler { call, result ->
                if (call.method != "previousExits") {
                    result.notImplemented()
                } else if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
                    result.success(emptyList<Map<String, Any>>())
                } else {
                    try {
                        val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                        result.success(manager.getHistoricalProcessExitReasons(context.packageName, 0, 8).map {
                            mapOf(
                                "timestamp" to it.timestamp,
                                "reason" to it.reason,
                                "status" to it.status,
                                "importance" to it.importance,
                                "pssKiB" to it.pss,
                                "rssKiB" to it.rss,
                            )
                        })
                    } catch (error: Exception) {
                        result.error("exit_history_unavailable", error.javaClass.simpleName, null)
                    }
                }
            }
    }
}
