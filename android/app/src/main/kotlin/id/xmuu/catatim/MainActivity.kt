package id.xmuu.catatim

import android.app.Notification
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {

    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleSharedIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleSharedIntent(intent)
    }

    private fun handleSharedIntent(intent: Intent?) {
        if (intent == null || intent.action != Intent.ACTION_SEND) return
        val type = intent.type ?: return
        if (type.startsWith("text/")) {
            val text = intent.getStringExtra(Intent.EXTRA_TEXT)
                ?: intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
            if (!text.isNullOrBlank()) {
                pendingSharedPayload = mapOf("type" to "text", "text" to text)
            }
        } else if (type.startsWith("image/")) {
            @Suppress("DEPRECATION")
            val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM) ?: return
            // Audit P-1: salinan bisa beberapa MB (foto kamera) — jangan
            // diblokir di main thread saat onCreate/onNewIntent (risiko
            // ANR saat cold start). Pakai thread IO yang sama dengan
            // antrean capture; pendingSharedPayload sudah @Volatile.
            val appContext = applicationContext
            ioHandler.post {
                try {
                    appContext.contentResolver.openInputStream(uri)?.use { input ->
                        val file = File(appContext.cacheDir, "shared_ocr_${System.currentTimeMillis()}.jpg")
                        FileOutputStream(file).use { output ->
                            input.copyTo(output)
                        }
                        pendingSharedPayload = mapOf("type" to "image", "path" to file.absolutePath)
                    }
                } catch (e: Exception) {
                    // Audit P-11: kegagalan senyap membuat user mengira
                    // share gagal diam-diam. Pesan statis — tanpa payload.
                    Log.w("catatim-capture", "gagal menyalin gambar share", e)
                }
            }
        }
    }

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
                    "drainQueue" -> NotificationCatcher.drainQueue(this) { lines ->
                        result.success(lines)
                    }
                    "getLastCaptureHeartbeat" -> result.success(NotificationCatcher.getLastHeartbeatAt(this))
                    "listLaunchableApps" -> {
                        val pm = packageManager
                        val intent = Intent(Intent.ACTION_MAIN).addCategory(
                            Intent.CATEGORY_LAUNCHER
                        )
                        val apps = pm.queryIntentActivities(intent, 0)
                            .mapNotNull { info ->
                                val pkg = info.activityInfo?.packageName ?: return@mapNotNull null
                                if (pkg == packageName) return@mapNotNull null
                                val label = pm.getApplicationLabel(
                                    info.activityInfo.applicationInfo
                                ).toString()
                                mapOf("package" to pkg, "label" to label)
                            }
                            .sortedBy { (it["label"] as String).lowercase() }
                        result.success(apps)
                    }
                    "getActiveNotifications" -> {
                        result.success(NotificationCatcher.getActiveNotificationLines(this))
                    }
                    "consumeSharedPayload" -> {
                        val p = pendingSharedPayload
                        pendingSharedPayload = null
                        result.success(p)
                    }
                    "simulateNotification" -> {
                        val pkg = call.argument<String>("packageName") ?: "com.bcadigital.blu"
                        val title = call.argument<String>("title").orEmpty()
                        val body = call.argument<String>("body").orEmpty()
                        val postedAt = (call.argument<Number>("postedAt"))?.toLong() ?: System.currentTimeMillis()
                        val json = JSONObject()
                            .put("packageName", pkg)
                            .put("title", title)
                            .put("body", body)
                            .put("postedAt", postedAt)
                            .toString()
                        val current = NotificationCatcher.sink
                        if (current != null) {
                            mainHandler.post { runCatching { current.success(json) } }
                        } else {
                            NotificationCatcher.enqueue(this, json)
                        }
                        result.success(true)
                    }
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

        // Peringatan batas (ADR-012): Dart memutuskan kapan & apa;
        // native hanya cek izin dan menampilkan notifikasinya.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canPost" -> result.success(BudgetNotifier.canPost(this))
                    "needsRuntimePermission" ->
                        result.success(BudgetNotifier.needsRuntimePermission(this))
                    "requestPermission" -> {
                        if (BudgetNotifier.needsRuntimePermission(this)) {
                            pendingPermissionResult = result
                            requestPermissions(
                                arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                                REQUEST_POST_PERMISSION,
                            )
                        } else {
                            // < Android 13: state berupa izin sistem saat ini.
                            result.success(BudgetNotifier.canPost(this))
                        }
                    }
                    "openAppNotificationSettings" -> {
                        BudgetNotifier.openAppNotificationSettings(this)
                        result.success(null)
                    }
                    "show" -> {
                        val title = call.argument<String>("title").orEmpty()
                        val body = call.argument<String>("body").orEmpty()
                        BudgetNotifier.show(applicationContext, title, body)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_POST_PERMISSION) return
        val pending = pendingPermissionResult
        pendingPermissionResult = null
        pending?.success(
            grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED,
        )
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
        const val METHOD_CHANNEL = "catatim/capture"
        const val EVENT_CHANNEL = "catatim/capture_events"
        const val NOTIFY_CHANNEL = "catatim/notify"
        const val REQUEST_POST_PERMISSION = 4001

        @Volatile
        var pendingSharedPayload: Map<String, Any?>? = null

        @Volatile
        var pendingPermissionResult: MethodChannel.Result? = null
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

        @Volatile
        var instance: NotificationCatcher? = null
        private const val QUEUE_FILE = "capture_queue.jsonl"
        private val lock = Any()
        private const val QUEUE_MAX_BYTES = 1_000_000L
        private const val QUEUE_KEEP_LINES = 1000

        /// I/O antrian (tulis + baca-hapus) berjalan di thread ini —
        /// jangan pernah sentuh file di main thread; notifikasi bisa
        /// datang beruntun saat UI sedang aktif. FIFO: urutan enqueue
        /// vs drain tetap terjaga karena satu thread yang sama.
        private val ioThread = HandlerThread("catatim-capture-io").apply { start() }
        private val ioHandler = Handler(ioThread.looper)
        private val replyHandler = Handler(Looper.getMainLooper())

        private const val PREFS = "catatim_capture"
        private const val KEY_ALLOWED = "allowed_packages"
        private const val KEY_LEARNED = "learned_packages"
        private const val KEY_LAST_HEARTBEAT = "last_heartbeat_at"

        /// Audit P-5: onNotificationPosted dipanggil untuk SETIAP
        /// notifikasi dari SEMUA app — tanpa throttle berarti satu
        /// tulisan prefs per notifikasi. Heartbeat hanya indikator
        /// kebugaran (Dart membacanya untuk "lampu sehat"), jadi tulis
        /// disk maksimal sekali per menit; proses restart → nilai
        /// in-memory 0 → tulisan pertama langsung lewat.
        private const val HEARTBEAT_MIN_INTERVAL_MS = 60_000L

        @Volatile
        private var lastHeartbeatWriteAt = 0L

        fun recordHeartbeat(context: Context) {
            val now = System.currentTimeMillis()
            val last = lastHeartbeatWriteAt
            if (last != 0L && now - last < HEARTBEAT_MIN_INTERVAL_MS) return
            lastHeartbeatWriteAt = now
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .putLong(KEY_LAST_HEARTBEAT, now)
                .apply()
        }

        fun getLastHeartbeatAt(context: Context): Long {
            return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getLong(KEY_LAST_HEARTBEAT, 0L)
        }

        /// Dorong daftar paket bank terhubung dari Dart. Hanya paket
        /// dalam daftar ini (plus yang sudah dipelajari) yang boleh
        /// ditulis ke antrean disk — OTP/notifikasi app lain tak pernah
        /// menyentuh storage. Native tetap transport: daftar datang
        /// dari Dart, di sini hanya disimpan dan dicocokkan.
        fun setAllowedPackages(context: Context, packages: List<String>) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            if (packages.isEmpty()) {
                // Tidak ada bank terhubung → jangan antrikan apa pun,
                // termasuk paket belajar (audit C-05): memutus semua
                // bank harus benar-benar menghentikan tulisan ke disk.
                prefs.edit().putStringSet(KEY_ALLOWED, emptySet()).apply()
                return
            }
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

        /// Fire-and-forget: tulisan dijadwalkan di IO thread, pemanggil
        /// (onNotificationPosted / receiver) tidak pernah menunggu disk.
        /// Context dinormalkan ke applicationContext agar tidak menggantung
        /// referensi activity di antrean yang berjalan belakangan.
        fun enqueue(context: Context, line: String) {
            ioHandler.post { writeToQueue(context.applicationContext, line) }
        }

        private fun writeToQueue(context: Context, line: String) {
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

        /// Baca-hapus antrian di IO thread, jawab via callback di main
        /// thread (MethodChannel result wajib di main).
        fun drainQueue(context: Context, onDone: (List<String>) -> Unit) {
            ioHandler.post {
                val lines = synchronized(lock) {
                    val file = File(context.applicationContext.filesDir, QUEUE_FILE)
                    if (!file.exists()) return@synchronized emptyList()
                    val result = file.readLines().filter { it.isNotBlank() }
                    file.delete()
                    result
                }
                replyHandler.post { onDone(lines) }
            }
        }

        fun lineFromSbn(context: Context, sbn: StatusBarNotification, checkAllowed: Boolean = false): String? {
            if (sbn.packageName == context.packageName) return null
            if (sbn.isOngoing) return null

            if (checkAllowed && !isAllowed(context, sbn.packageName)) {
                return null
            }

            val extras = sbn.notification?.extras ?: return null
            val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
            val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString().orEmpty()
            val big = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString().orEmpty()
            val body = if (big.length > text.length) big else text
            if (title.isBlank() && body.isBlank()) return null
            if (body.contains("Sensitive notification content hidden")) return null

            return JSONObject()
                .put("packageName", sbn.packageName)
                .put("title", title)
                .put("body", body)
                .put("postedAt", sbn.postTime)
                .toString()
        }

        fun getActiveNotificationLines(context: Context): List<String> {
            val catcher = instance ?: return emptyList()
            val active = try {
                catcher.activeNotifications ?: emptyArray()
            } catch (_: Exception) {
                emptyArray()
            }
            return active.mapNotNull { sbn ->
                lineFromSbn(context, sbn, checkAllowed = true)
            }
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onListenerConnected() {
        super.onListenerConnected()
        instance = this
        recordHeartbeat(applicationContext)
    }

    override fun onDestroy() {
        super.onDestroy()
        if (instance == this) {
            instance = null
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        recordHeartbeat(applicationContext)
        val line = lineFromSbn(applicationContext, sbn, checkAllowed = false) ?: return

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

/**
 * Receiver simulasi notifikasi untuk pengujian otomatisasi dan pengujian manual
 * via `adb shell am broadcast -a id.xmuu.catatim.SIMULATE_NOTIFICATION ...`
 */
class NotificationSimulatorReceiver : BroadcastReceiver() {
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_SIMULATE) return
        // Gerbang simulasi hanya untuk build debug; build rilis (Play)
        // kebal injeksi notifikasi palsu dari app lain.
        val debuggable =
            context.applicationInfo.flags and
                android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE
        if (debuggable == 0) return
        val pkg = intent.getStringExtra("package")
            ?: intent.getStringExtra("packageName")
            ?: "com.bcadigital.blu"
        val title = intent.getStringExtra("title").orEmpty()
        val body = intent.getStringExtra("body")
            ?: intent.getStringExtra("text").orEmpty()
        val postedAt = intent.getLongExtra("postedAt", System.currentTimeMillis())

        val json = JSONObject()
            .put("packageName", pkg)
            .put("title", title)
            .put("body", body)
            .put("postedAt", postedAt)
            .toString()

        val currentSink = NotificationCatcher.sink
        if (currentSink != null) {
            mainHandler.post { runCatching { currentSink.success(json) } }
        } else {
            NotificationCatcher.enqueue(context.applicationContext, json)
        }
    }

    companion object {
        const val ACTION_SIMULATE = "id.xmuu.catatim.SIMULATE_NOTIFICATION"
    }
}
