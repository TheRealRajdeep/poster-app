package com.example.wa_share

import android.app.Activity
import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File

/**
 * Shares an image straight into WhatsApp (or WhatsApp Business), so the
 * WhatsApp picker opens with "My status" at the top, skipping the generic
 * Android share sheet. Falls back to the system chooser when no target is given.
 *
 * Channel methods:
 *  - installedPackages() -> List<String> of installed WhatsApp package names
 *  - shareImage(path, mimeType, caption?, package?) -> "launched" | "not_installed"
 */
class WaSharePlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        try {
            when (call.method) {
                "installedPackages" -> result.success(WHATSAPP_PACKAGES.filter(::isInstalled))
                "shareImage" -> result.success(
                    shareImage(
                        path = call.argument<String>("path")
                            ?: return result.error("bad_args", "path is required", null),
                        mimeType = call.argument<String>("mimeType") ?: "image/png",
                        caption = call.argument<String>("caption"),
                        targetPackage = call.argument<String>("package"),
                    )
                )
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("share_failed", e.message, e.javaClass.simpleName)
        }
    }

    private fun isInstalled(pkg: String): Boolean = try {
        if (Build.VERSION.SDK_INT >= 33) {
            context.packageManager.getPackageInfo(pkg, PackageManager.PackageInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            context.packageManager.getPackageInfo(pkg, 0)
        }
        true
    } catch (_: PackageManager.NameNotFoundException) {
        false
    }

    private fun shareImage(path: String, mimeType: String, caption: String?, targetPackage: String?): String {
        if (targetPackage != null && !isInstalled(targetPackage)) return "not_installed"

        // Copy into our FileProvider directory; a fresh name per share stops
        // WhatsApp from showing a cached older poster.
        val dir = File(context.cacheDir, "wa_share").apply { mkdirs() }
        dir.listFiles()?.forEach { it.delete() }
        val ext = File(path).extension.ifEmpty { "png" }
        val shared = File(dir, "poster_${System.currentTimeMillis()}.$ext")
        File(path).copyTo(shared, overwrite = true)
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.wa_share.fileprovider", shared)

        val send = Intent(Intent.ACTION_SEND).apply {
            type = mimeType
            putExtra(Intent.EXTRA_STREAM, uri)
            if (!caption.isNullOrBlank()) putExtra(Intent.EXTRA_TEXT, caption)
            clipData = ClipData.newRawUri("poster", uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            if (targetPackage != null) setPackage(targetPackage)
        }
        val intent = if (targetPackage != null) send else Intent.createChooser(send, null)

        val host = activity
        if (host != null) {
            host.startActivity(intent)
        } else {
            context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
        return "launched"
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    companion object {
        const val CHANNEL = "wa_share"
        val WHATSAPP_PACKAGES = listOf("com.whatsapp", "com.whatsapp.w4b")
    }
}
