package id.xmuu.catatim

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings

/**
 * Transport tampil notifikasi lokal peringatan batas (ADR-012 —
 * konsisten ADR-001): lapisan ini HANYA membuat channel, mengecek
 * izin, dan menampilkan notifikasi berteks dari Dart. Semua keputusan
 * (kapan mengingatkan, garis mana, berapa persen) di Dart.
 */
object BudgetNotifier {

    private const val CHANNEL_ID = "budget_alerts"
    private const val REMINDER_CHANNEL_ID = "reminders"
    private const val NOTIF_ID = 2001

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < 26) return
        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(CHANNEL_ID) == null) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Peringatan Batas",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "Peringatan saat pengeluaran menyentuh persentase batas"
            }
            manager.createNotificationChannel(channel)
        }
        if (manager.getNotificationChannel(REMINDER_CHANNEL_ID) == null) {
            val reminderChannel = NotificationChannel(
                REMINDER_CHANNEL_ID,
                "Pengingat Terjadwal",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "Pengingat catat harian dan jatuh tempo bon"
            }
            manager.createNotificationChannel(reminderChannel)
        }
    }

    /** Izin notifikasi app aktif dan channel tidak dimatikan user. */
    fun canPost(context: Context): Boolean {
        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (!manager.areNotificationsEnabled()) return false
        if (Build.VERSION.SDK_INT >= 26) {
            val channel = manager.getNotificationChannel(CHANNEL_ID) ?: return true
            return channel.importance != NotificationManager.IMPORTANCE_NONE
        }
        return true
    }

    /** True bila butuh dialog runtime POST_NOTIFICATIONS (Android 13+). */
    fun needsRuntimePermission(context: Context): Boolean =
        Build.VERSION.SDK_INT >= 33 &&
            context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED

    fun openAppNotificationSettings(context: Context) {
        val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
            .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
    }

    fun show(context: Context, title: String, body: String) {
        showInChannel(context, CHANNEL_ID, NOTIF_ID, title, body)
    }

    fun showReminder(context: Context, id: Int, title: String, body: String) {
        showInChannel(context, REMINDER_CHANNEL_ID, id, title, body)
    }

    private fun showInChannel(
        context: Context,
        channelId: String,
        notifId: Int,
        title: String,
        body: String,
    ) {
        ensureChannel(context)
        if (!canPost(context)) return
        val builder = if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(context, channelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
        if (launch != null) {
            builder.setContentIntent(
                PendingIntent.getActivity(
                    context,
                    0,
                    launch,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )
        }
        val notification = builder
            .setSmallIcon(context.applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .build()
        try {
            val manager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.notify(notifId, notification)
        } catch (_: SecurityException) {
            // Izin dicabut di tengah jalan — jangan crash.
        }
    }

    fun schedule(
        context: Context,
        id: Int,
        triggerAtMillis: Long,
        title: String,
        body: String,
    ) {
        ensureChannel(context)
        val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pending = reminderPendingIntent(context, id, title, body)
        if (Build.VERSION.SDK_INT >= 23) {
            alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pending)
        } else {
            alarm.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, pending)
        }
    }

    fun cancel(context: Context, id: Int) {
        val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, ReminderReceiver::class.java)
        val pending = PendingIntent.getBroadcast(
            context,
            id,
            intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
        )
        if (pending != null) {
            alarm.cancel(pending)
            pending.cancel()
        }
    }

    private fun reminderPendingIntent(
        context: Context,
        id: Int,
        title: String,
        body: String,
    ): PendingIntent {
        val intent = Intent(context, ReminderReceiver::class.java)
            .putExtra(ReminderReceiver.EXTRA_ID, id)
            .putExtra(ReminderReceiver.EXTRA_TITLE, title)
            .putExtra(ReminderReceiver.EXTRA_BODY, body)
        return PendingIntent.getBroadcast(
            context,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
