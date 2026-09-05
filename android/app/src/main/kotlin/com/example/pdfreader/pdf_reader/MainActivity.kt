package com.example.pdfreader.pdf_reader

import android.net.Uri
import android.provider.OpenableColumns
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

                    var displayName = "Documento.pdf"
                    val cursor = contentResolver.query(uri, null, null, null, null)
                    cursor?.use {
                        if (it.moveToFirst()) {
                            val nameIndex = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                            if (nameIndex != -1) {
                                val name = it.getString(nameIndex)
                                if (!name.isNullOrBlank()) {
                                    displayName = name
                                }
                            }
                        }
                    }

                    if (!displayName.lowercase().endsWith(".pdf")) {
                        displayName += ".pdf"
                    }

                    val inputStream = contentResolver.openInputStream(uri)
                    if (inputStream == null) {
                        result.error("CANNOT_OPEN", "InputStream is null", null)
                        return@setMethodCallHandler
                    }

                    val cacheDir = File(context.cacheDir, "shared_pdfs")
                    if (!cacheDir.exists()) {
                        cacheDir.mkdirs()
                    }

                    val safeName = displayName.replace(Regex("[^a-zA-Z0-9._-]"), "_")
                    val cacheFile = File(cacheDir, safeName)

                    val outputStream = FileOutputStream(cacheFile)
                    inputStream.copyTo(outputStream)
                    inputStream.close()
                    outputStream.close()

                    val response = mapOf(
                        "path" to cacheFile.absolutePath,
                        "name" to displayName
                    )
                    result.success(response)
                } catch (e: Exception) {
                    result.error("ERROR", e.localizedMessage, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
