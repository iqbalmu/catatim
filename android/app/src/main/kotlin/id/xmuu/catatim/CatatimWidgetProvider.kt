package id.xmuu.catatim

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews

/**
 * Widget home screen Android: menampilkan maskot dinamis ukuran besar,
 * sisa jatah hari ini, pengeluaran hari ini + draf, serta tombol `+ Catat`.
 * Tidak menampilkan total saldo demi privasi di layar utama.
 */
class CatatimWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val headline = prefs.getString(KEY_HEADLINE, "Sisa jatah hari ini") ?: "Sisa jatah hari ini"
        val primary = prefs.getString(KEY_PRIMARY, "Rp0") ?: "Rp0"
        val secondary = prefs.getString(KEY_SECONDARY, "Keluar: Rp0") ?: "Keluar: Rp0"
        val mood = prefs.getString(KEY_MOOD, "happy") ?: "happy"
        val isOver = prefs.getBoolean(KEY_IS_OVER, false)

        val mascotRes = when (mood) {
            "celebrate" -> R.drawable.widget_mascot_celebrate
            "worried" -> R.drawable.widget_mascot_worried
            "broke" -> R.drawable.widget_mascot_broke
            else -> R.drawable.widget_mascot
        }
        val primaryColor = if (isOver) Color.parseColor("#FDA4AF") else Color.WHITE
        val headlineColor = if (isOver) Color.parseColor("#FDA4AF") else Color.parseColor("#5EEAD4")

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.catatim_widget)
            views.setImageViewResource(R.id.widget_mascot, mascotRes)
            views.setTextViewText(R.id.widget_headline, headline)
            views.setTextColor(R.id.widget_headline, headlineColor)
            views.setTextViewText(R.id.widget_primary_amount, primary)
            views.setTextColor(R.id.widget_primary_amount, primaryColor)
            views.setTextViewText(R.id.widget_secondary_info, secondary)

            val openIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            views.setOnClickPendingIntent(
                R.id.widget_root,
                PendingIntent.getActivity(
                    context,
                    100,
                    openIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )

            val addIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra(EXTRA_ACTION, ACTION_QUICK_ADD)
            }
            views.setOnClickPendingIntent(
                R.id.widget_add_btn,
                PendingIntent.getActivity(
                    context,
                    101,
                    addIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    companion object {
        private const val PREFS_NAME = "catatim_widget"
        private const val KEY_HEADLINE = "headline"
        private const val KEY_PRIMARY = "primary_amount"
        private const val KEY_SECONDARY = "secondary_info"
        private const val KEY_MOOD = "mood"
        private const val KEY_IS_OVER = "is_over"

        const val EXTRA_ACTION = "catatim_widget_action"
        const val ACTION_QUICK_ADD = "quick_add"

        fun update(
            context: Context,
            headline: String,
            primaryAmount: String,
            secondaryInfo: String,
            mood: String,
            isOver: Boolean,
        ) {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putString(KEY_HEADLINE, headline)
                .putString(KEY_PRIMARY, primaryAmount)
                .putString(KEY_SECONDARY, secondaryInfo)
                .putString(KEY_MOOD, mood)
                .putBoolean(KEY_IS_OVER, isOver)
                .apply()

            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, CatatimWidgetProvider::class.java),
            )
            if (ids.isNotEmpty()) {
                CatatimWidgetProvider().onUpdate(context, manager, ids)
            }
        }
    }
}
