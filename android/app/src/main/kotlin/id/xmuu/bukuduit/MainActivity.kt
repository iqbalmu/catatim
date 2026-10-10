package id.xmuu.bukuduit

import android.app.Notification
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File

class MainActivity : FlutterActivity() {

    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isListenerEnabled" -> result.success(isListenerEnabled())
                    "openListenerSettings" -> {
                        startActivity(
                            Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                        )
                        result.success(null)
                    }
                    "drainQueue" -> result.success(NotificationCatcher.drainQueue(this))
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    NotificationCatcher.sink = events
                }

                override fun onCancel(arguments: Any?) {
                    NotificationCatcher.sink = null
                }
            })
    }

    private fun isListenerEnabled(): Boolean {
        val raw = Settings.Secure.getString(
            contentResolver,
            "enabled_notification_listeners"
        ) ?: return false
        return raw.split(":").any {
            it.substringBefore('/').equals(packageName, ignoreCase = true)
        }
    }

    companion object {
        const val METHOD_CHANNEL = "bukuduit/capture"
        const val EVENT_CHANNEL = "bukuduit/capture_events"
    }
}

/**
 * Transport notifikasi: sistem memanggil onNotificationPosted, lapisan ini
 * HANYA meneruskan JSON mentah (transport) — semua parsing di Dart.
 *
 * Setiap notifikasi juga ditulis ke antrian file agar tidak hilang bila
 * engine Flutter belum aktif; Dart mengosongkan antrian saat startup.
 */
class NotificationCatcher : NotificationListenerService() {

    companion object {
        @Volatile
        var sink: EventChannel.EventSink? = null

        private const val QUEUE_FILE = "capture_queue.jsonl"
        private val lock = Any()

        fun enqueue(context: Context, line: String) {
            synchronized(lock) {
                File(context.filesDir, QUEUE_FILE).appendText(line + "\n")
            }
        }

        fun drainQueue(context: Context): List<String> {
            synchronized(lock) {
                val file = File(context.filesDir, QUEUE_FILE)
                if (!file.exists()) return emptyList()
                val lines = file.readLines().filter { it.isNotBlank() }
                file.delete()
                return lines
            }
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.packageName == packageName) return

        val extras = sbn.notification?.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString().orEmpty()
        val big = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString().orEmpty()
        val body = if (big.length > text.length) big else text
        if (title.isBlank() && body.isBlank()) return

        val line = JSONObject()
            .put("packageName", sbn.packageName)
            .put("title", title)
            .put("body", body)
            .put("postedAt", sbn.postTime)
            .toString()

        enqueue(applicationContext, line)

        val current = sink ?: return
        mainHandler.post { runCatching { current.success(line) } }
    }
}
