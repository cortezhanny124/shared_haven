package com.bitcoin.sharedhaven.testnet

import android.database.Cursor
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.flutter_wallet/uri")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "resolveToCache" -> {
                        val uriStr = call.argument<String>("uri") ?: ""
                        try {
                            val uri = Uri.parse(uriStr)
                            val name = queryDisplayName(uri) ?: "import.sh.json"
                            val outFile = File(cacheDir, name)
                            contentResolver.openInputStream(uri).use { input ->
                                outFile.outputStream().use { output ->
                                    input?.copyTo(output)
                                }
                            }
                            result.success(outFile.absolutePath)
                        } catch (e: Exception) {
                            result.error("IO", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun queryDisplayName(uri: Uri): String? {
        var name: String? = null
        val projection = arrayOf(OpenableColumns.DISPLAY_NAME)
        val cursor: Cursor? = contentResolver.query(uri, projection, null, null, null)
        cursor?.use { if (it.moveToFirst()) name = it.getString(0) }
        return name
    }
}
