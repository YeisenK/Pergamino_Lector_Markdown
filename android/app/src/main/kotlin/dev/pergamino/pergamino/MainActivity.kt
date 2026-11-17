package dev.pergamino.pergamino

import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pending: Map<String, String>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pergamino/incoming")
        channel!!.setMethodCallHandler { call, result ->
            if (call.method == "initial") {
                result.success(pending ?: extract(intent))
                pending = null
            } else result.notImplemented()
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        extract(intent)?.let { channel?.invokeMethod("file", it) }
    }

    /** Copia el contenido (content://) a la caché y devuelve su ruta. */
    private fun extract(intent: Intent?): Map<String, String>? {
        if (intent == null) return null
        val uri: Uri? = when (intent.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND ->
                @Suppress("DEPRECATION") intent.getParcelableExtra(Intent.EXTRA_STREAM)
            else -> null
        }
        if (uri == null) return null
        return try {
            var name = "libro.md"
            contentResolver.query(uri, null, null, null, null)?.use { c ->
                val i = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (i >= 0 && c.moveToFirst()) name = c.getString(i) ?: name
            }
            val out = File(cacheDir, "incoming_${System.currentTimeMillis()}.md")
            contentResolver.openInputStream(uri)?.use { input ->
                out.outputStream().use { input.copyTo(it) }
            } ?: return null
            // evita reimportar el mismo intent al recrear la actividad
            intent.action = null
            mapOf("path" to out.absolutePath, "name" to name)
        } catch (e: Exception) {
            null
        }
    }
}
