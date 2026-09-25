package com.antigravity.valhalla.valhalla

import android.content.Context
import android.net.wifi.WifiManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

object NasNetworkChannel {
    private var multicastLock: WifiManager.MulticastLock? = null

    fun register(context: Context, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "valhalla/nas_network")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "acquireMulticast" -> {
                            val wifi = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                            val lock = multicastLock ?: wifi.createMulticastLock("valhalla-dlna-discovery").also {
                                it.setReferenceCounted(false)
                                multicastLock = it
                            }
                            if (!lock.isHeld) lock.acquire()
                            result.success(null)
                        }
                        "releaseMulticast" -> {
                            multicastLock?.let { if (it.isHeld) it.release() }
                            multicastLock = null
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("NAS_MULTICAST_PERMISSION", error.javaClass.simpleName, null)
                }
            }
    }
}
