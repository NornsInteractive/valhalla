package com.antigravity.valhalla.valhalla

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

object UpdateChannel {
    private fun flags(): Int = if (Build.VERSION.SDK_INT >= 28)
        PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES

    @Suppress("DEPRECATION")
    private fun certificates(info: PackageInfo): Set<String> {
        val signatures = if (Build.VERSION.SDK_INT >= 28)
            info.signingInfo?.apkContentsSigners else info.signatures
        return signatures?.map {
            MessageDigest.getInstance("SHA-256").digest(it.toByteArray())
                .joinToString("") { byte -> "%02x".format(byte.toInt() and 255) }
        }?.toSet() ?: emptySet()
    }

    @Suppress("DEPRECATION")
    private fun version(info: PackageInfo): Long = if (Build.VERSION.SDK_INT >= 28)
        info.longVersionCode else info.versionCode.toLong()

    fun register(activity: Activity, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "valhalla/updates")
            .setMethodCallHandler { call, result ->
                try {
                    val manager = activity.packageManager
                    val installed = manager.getPackageInfo(activity.packageName, flags())
                    val installer = if (Build.VERSION.SDK_INT >= 30)
                        manager.getInstallSourceInfo(activity.packageName).installingPackageName
                    else @Suppress("DEPRECATION") manager.getInstallerPackageName(activity.packageName)
                    val storeInstall = installer == "com.android.vending"
                    when (call.method) {
                        "runtimeInfo" -> result.success(mapOf(
                            "abis" to Build.SUPPORTED_ABIS.toList(),
                            "baseBuildNumber" to (version(installed) % 1000).toInt(),
                            "storeInstall" to storeInstall,
                        ))
                        "install" -> {
                            if (storeInstall) {
                                result.error("UPDATE_STORE_INSTALL", null, null)
                                return@setMethodCallHandler
                            }
                            val path = call.argument<String>("path") ?: ""
                            val file = File(path).canonicalFile
                            val downloads = File(activity.filesDir, "downloads").canonicalFile
                            if (!file.isFile || file.extension != "apk" ||
                                !file.toPath().startsWith(downloads.toPath())) {
                                result.error("UPDATE_PACKAGE_PATH_INVALID", null, null)
                                return@setMethodCallHandler
                            }
                            val archive = manager.getPackageArchiveInfo(file.path, flags())
                            val expectedVersion = call.argument<Number>("versionCode")?.toLong()
                            val expectedName = call.argument<String>("versionName")
                            val expectedCertificate = call.argument<String>("certificateSha256")
                            if (archive == null || archive.packageName != activity.packageName ||
                                version(archive) <= version(installed) ||
                                (expectedVersion != null && version(archive) != expectedVersion) ||
                                (expectedName != null && archive.versionName != expectedName)) {
                                result.error("UPDATE_PACKAGE_IDENTITY_INVALID", null, null)
                                return@setMethodCallHandler
                            }
                            val actual = certificates(archive)
                            if (actual.isEmpty() || actual != certificates(installed) ||
                                (expectedCertificate != null && actual != setOf(expectedCertificate.lowercase()))) {
                                result.error("UPDATE_SIGNATURE_MISMATCH", null, null)
                                return@setMethodCallHandler
                            }
                            if (Build.VERSION.SDK_INT >= 26 && !manager.canRequestPackageInstalls()) {
                                activity.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                    Uri.parse("package:${activity.packageName}")))
                                result.error("UPDATE_INSTALL_PERMISSION_REQUIRED", null, null)
                                return@setMethodCallHandler
                            }
                            val uri = FileProvider.getUriForFile(activity,
                                "${activity.packageName}.fileprovider", file)
                            activity.startActivity(Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(uri, "application/vnd.android.package-archive")
                                flags = Intent.FLAG_GRANT_READ_URI_PERMISSION
                            })
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (_: Exception) {
                    result.error("UPDATE_PLATFORM_FAILED", null, null)
                }
            }
    }
}
