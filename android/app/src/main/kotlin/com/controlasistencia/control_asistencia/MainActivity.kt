package com.controlasistencia.control_asistencia

import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.controlasistencia.control_asistencia/email",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getContentUri" -> {
                    val path = call.arguments as? String
                    if (path.isNullOrBlank()) {
                        result.error("invalid_path", "Ruta invalida", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val file = File(path)
                        val uri: Uri = FileProvider.getUriForFile(
                            this,
                            "${applicationContext.packageName}.fileprovider",
                            file,
                        )
                        result.success(uri.toString())
                    } catch (e: Exception) {
                        result.error("uri_error", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
