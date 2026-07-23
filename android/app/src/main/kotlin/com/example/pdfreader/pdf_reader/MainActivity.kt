package com.example.pdfreader.pdf_reader

import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.pdfreader/content_resolver"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "copyContentUriToCache") {
                val uriString = call.argument<String>("uri")
                if (uriString == null) {
                    result.error("INVALID_URI", "URI is null", null)
                    return@setMethodCallHandler
                }
                try {
                    val uri = Uri.parse(uriString)
                    val inputStream = contentResolver.openInputStream(uri)
                    if (inputStream == null) {
                        result.error("CANNOT_OPEN", "InputStream is null", null)
                        return@setMethodCallHandler
                    }

                    val cacheFile = File(context.cacheDir, "shared_document.pdf")
                    val outputStream = FileOutputStream(cacheFile)
                    inputStream.copyTo(outputStream)
                    inputStream.close()
                    outputStream.close()

                    result.success(cacheFile.absolutePath)
                } catch (e: Exception) {
                    result.error("ERROR", e.localizedMessage, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
