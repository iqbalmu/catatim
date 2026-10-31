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
                    "openBatterySettings" -> {
                        startActivity(
                            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                        )
                        result.success(null)
                    }
                    "setAllowedPackages" -> {
                        val pkgs = (call.arguments as? List<*>)
                            ?.filterIsInstance<String>()
                            ?: emptyList()
                        NotificationCatcher.setAllowedPackages(this, pkgs)
                        result.success(null)
                    }
                    "learnBankPackage" -> {
                        val pkg = call.arguments as? String
                        if (pkg != null) NotificationCatcher.learnPackage(this, pkg)
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
        private const val QUEUE_MAX_BYTES = 1_000_000L
        private const val QUEUE_KEEP_LINES = 1000

        private const val PREFS = "bukuduit_capture"
        private const val KEY_ALLOWED = "allowed_packages"
        private const val KEY_LEARNED = "learned_packages"

        /// Dorong daftar paket bank terhubung dari Dart. Hanya paket
        /// dalam daftar ini (plus yang sudah dipelajari) yang boleh
        /// ditulis ke antrean disk — OTP/notifikasi app lain tak pernah
        /// menyentuh storage. Native tetap transport: daftar datang
        /// dari Dart, di sini hanya disimpan dan dicocokkan.
        fun setAllowedPackages(context: Context, packages: List<String>) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val learned = prefs.getStringSet(KEY_LEARNED, emptySet()) ?: emptySet()
            prefs.edit()
                .putStringSet(KEY_ALLOWED, packages.toSet() + learned)
                .apply()
        }

        /// Paket yang ternyata milik bank terhubung (dicocokkan Dart
        /// lewat keyword, mis. bank tanpa packageNames) — antrikan
        /// notifikasi paket ini selanjutnya.
        fun learnPackage(context: Context, pkg: String) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val learned = prefs.getStringSet(KEY_LEARNED, emptySet()) ?: emptySet()
            if (pkg in learned) return
            val allowed = prefs.getStringSet(KEY_ALLOWED, emptySet()) ?: emptySet()
            prefs.edit()
                .putStringSet(KEY_LEARNED, learned + pkg)
                .putStringSet(KEY_ALLOWED, allowed + pkg)
                .apply()
        }

        private fun isAllowed(context: Context, pkg: String): Boolean {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val allowed = prefs.getStringSet(KEY_ALLOWED, emptySet()) ?: emptySet()
            return pkg in allowed
        }

        fun enqueue(context: Context, line: String) {
            synchronized(lock) {
                val file = File(context.filesDir, QUEUE_FILE)
                file.appendText(line + "\n")
                // Antrian hanya jaring pengaman saat app mati — jangan
                // biarkan tumbuh tanpa batas; simpan bagian terakhir.
                if (file.length() > QUEUE_MAX_BYTES) {
                    val keep = file.readLines().takeLast(QUEUE_KEEP_LINES)
                    file.writeText(
                        keep.joinToString(separator = "\n", postfix = "\n")
                    )
                }
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

        // Notifikasi "ongoing" (musik, unduhan, status menetap) bukan
        // transaksi — dilewati agar tidak menambah ukuran antrian.
        if (sbn.isOngoing) return

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

        // Hanya paket bank terhubung/pelajaran yang boleh menebar ke
        // disk; sink live tetap menerima semuanya agar Dart bisa
        // mencocokkan keyword dan mempelajari paket bank baru.
        if (isAllowed(applicationContext, sbn.packageName)) {
            enqueue(applicationContext, line)
        }

        val current = sink ?: return
        mainHandler.post { runCatching { current.success(line) } }
    }
}
