package id.xmuu.catatim

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Penerima alarm terjadwal (pengingat harian & jatuh tempo bon).
 * Konten sudah diputuskan di Dart saat jadwal dipasang (ADR-012).
 */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra(EXTRA_ID, 3001)
        val title = intent.getStringExtra(EXTRA_TITLE) ?: return
        val body = intent.getStringExtra(EXTRA_BODY).orEmpty()
        BudgetNotifier.showReminder(context, id, title, body)
    }

    companion object {
        const val EXTRA_ID = "id"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
    }
}
