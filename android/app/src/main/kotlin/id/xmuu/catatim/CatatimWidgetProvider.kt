package id.xmuu.catatim

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews

/**
 * Widget home screen bergaya Duolingo Companion (4×2 & 2×2):
 * - Kartu warna adaptif sesuai mood (Krem hangat / Berry / Crimson gelap)
 * - Angka Sisa Jatah + badge 🔥 streak di kiri atas
 * - Kalimat mood + progress bar jatah harian + Keluar Rp... & chip draf
 * - Maskot raksasa di-flip di pojok kanan bawah
 */
class CatatimWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        updateWidgets(context, appWidgetManager, appWidgetIds, defaultCompact = false)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        updateWidgets(
            context,
            appWidgetManager,
            intArrayOf(appWidgetId),
            defaultCompact = false,
        )
    }

    companion object {
        private const val PREFS_NAME = "catatim_widget"
        private const val KEY_HEADLINE = "headline"
        private const val KEY_COMPACT_HEADLINE = "compact_headline"
        private const val KEY_PRIMARY = "primary_amount"
        private const val KEY_SECONDARY = "secondary_info"
        private const val KEY_DRAFT_CHIP = "draft_chip"
        private const val KEY_STREAK_BADGE = "streak_badge"
        private const val KEY_PROGRESS = "progress_percent"
        private const val KEY_PROGRESS_LABEL = "progress_label"
        private const val KEY_HAS_PROGRESS = "has_progress"
        private const val KEY_MOOD = "mood"
        private const val KEY_IS_OVER = "is_over"
        private const val COMPACT_WIDTH_THRESHOLD_DP = 210

        const val EXTRA_ACTION = "catatim_widget_action"
        const val ACTION_QUICK_ADD = "quick_add"

        fun updateWidgets(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetIds: IntArray,
            defaultCompact: Boolean,
        ) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val headline = prefs.getString(KEY_HEADLINE, "Masih aman terkendali!")
                ?: "Masih aman terkendali!"
            val compactHeadline = prefs.getString(KEY_COMPACT_HEADLINE, "Keluar Rp0")
                ?: "Keluar Rp0"
            val primary = prefs.getString(KEY_PRIMARY, "Rp0") ?: "Rp0"
            val secondary = prefs.getString(KEY_SECONDARY, "Keluar Rp0") ?: "Keluar Rp0"
            val draftChip = prefs.getString(KEY_DRAFT_CHIP, "") ?: ""
            val streakBadge = prefs.getString(KEY_STREAK_BADGE, "") ?: ""
            val progress = prefs.getInt(KEY_PROGRESS, 0).coerceIn(0, 100)
            val progressLabel = prefs.getString(KEY_PROGRESS_LABEL, "${progress}%") ?: "${progress}%"
            val hasProgress = prefs.getBoolean(KEY_HAS_PROGRESS, false)
            val mood = prefs.getString(KEY_MOOD, "happy") ?: "happy"
            val isOver = prefs.getBoolean(KEY_IS_OVER, false)

            val mascotRes = when (mood) {
                "celebrate" -> R.drawable.widget_mascot_celebrate
                "worried" -> R.drawable.widget_mascot_worried
                "broke" -> R.drawable.widget_mascot_broke
                else -> R.drawable.widget_mascot
            }
            val isBroke = isOver || mood == "broke"
            val isWorried = !isBroke && mood == "worried"

            val cardRes = when {
                isBroke -> R.drawable.widget_card_broke
                isWorried -> R.drawable.widget_card_worried
                else -> R.drawable.widget_card_happy
            }
            val primaryColor = when {
                isBroke || isWorried -> Color.WHITE
                else -> Color.parseColor("#D97706")
            }
            val subtitleColor = when {
                isBroke -> Color.parseColor("#FECACA")
                isWorried -> Color.parseColor("#FBCFE8")
                else -> Color.parseColor("#8A6520")
            }
            val chipBgRes = when {
                isBroke -> R.drawable.widget_day_off_broke
                isWorried -> R.drawable.widget_day_off_worried
                else -> R.drawable.widget_day_off_happy
            }

            val openIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val openPending = PendingIntent.getActivity(
                context,
                100,
                openIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

            for (appWidgetId in appWidgetIds) {
                val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
                val minWidth = options.getInt(
                    AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH,
                    if (defaultCompact) 140 else 250,
                )
                val useCompact = minWidth < COMPACT_WIDTH_THRESHOLD_DP
                val layoutRes =
                    if (useCompact) R.layout.catatim_widget_compact else R.layout.catatim_widget

                val views = RemoteViews(context.packageName, layoutRes)
                views.setInt(R.id.widget_root, "setBackgroundResource", cardRes)
                views.setImageViewResource(R.id.widget_mascot, mascotRes)

                views.setTextViewText(R.id.widget_primary_amount, primary)
                views.setTextColor(R.id.widget_primary_amount, primaryColor)
                if (streakBadge.isNotEmpty()) {
                    views.setTextViewText(R.id.widget_streak_badge, streakBadge)
                    views.setTextColor(R.id.widget_streak_badge, primaryColor)
                    views.setViewVisibility(R.id.widget_streak_badge, View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.widget_streak_badge, View.GONE)
                }

                views.setTextViewText(
                    R.id.widget_headline,
                    if (useCompact) compactHeadline else headline,
                )
                views.setTextColor(R.id.widget_headline, subtitleColor)

                if (!useCompact) {
                    views.setTextViewText(
                        R.id.widget_eyebrow,
                        if (isBroke) "LEWAT JATAH HARI INI" else "SISA JATAH HARI INI",
                    )
                    views.setTextColor(R.id.widget_eyebrow, subtitleColor)
                    views.setTextViewText(R.id.widget_secondary_info, secondary)
                    views.setTextColor(R.id.widget_secondary_info, subtitleColor)
                }

                if (draftChip.isNotEmpty()) {
                    views.setTextViewText(R.id.widget_draft_chip, draftChip)
                    views.setTextColor(R.id.widget_draft_chip, subtitleColor)
                    views.setInt(R.id.widget_draft_chip, "setBackgroundResource", chipBgRes)
                    views.setViewVisibility(R.id.widget_draft_chip, View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.widget_draft_chip, View.GONE)
                }

                views.setViewVisibility(R.id.widget_progress_happy, View.GONE)
                views.setViewVisibility(R.id.widget_progress_worried, View.GONE)
                views.setViewVisibility(R.id.widget_progress_broke, View.GONE)
                if (!useCompact) {
                    views.setViewVisibility(
                        R.id.widget_progress_row,
                        if (hasProgress) View.VISIBLE else View.GONE,
                    )
                }
                if (hasProgress) {
                    val activeBarId = when {
                        isBroke -> R.id.widget_progress_broke
                        isWorried -> R.id.widget_progress_worried
                        else -> R.id.widget_progress_happy
                    }
                    views.setProgressBar(activeBarId, 100, progress, false)
                    views.setViewVisibility(activeBarId, View.VISIBLE)
                    if (!useCompact) {
                        views.setTextViewText(R.id.widget_progress_pct, progressLabel)
                        views.setTextColor(R.id.widget_progress_pct, subtitleColor)
                    }
                }

                views.setOnClickPendingIntent(R.id.widget_root, openPending)
                appWidgetManager.updateAppWidget(appWidgetId, views)
            }
        }

        fun update(
            context: Context,
            headline: String,
            compactHeadline: String,
            primaryAmount: String,
            secondaryInfo: String,
            draftChip: String,
            streakBadge: String,
            progressPercent: Int,
            progressLabel: String,
            hasProgress: Boolean,
            mood: String,
            isOver: Boolean,
        ) {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .putString(KEY_HEADLINE, headline)
                .putString(KEY_COMPACT_HEADLINE, compactHeadline)
                .putString(KEY_PRIMARY, primaryAmount)
                .putString(KEY_SECONDARY, secondaryInfo)
                .putString(KEY_DRAFT_CHIP, draftChip)
                .putString(KEY_STREAK_BADGE, streakBadge)
                .putInt(KEY_PROGRESS, progressPercent)
                .putString(KEY_PROGRESS_LABEL, progressLabel)
                .putBoolean(KEY_HAS_PROGRESS, hasProgress)
                .putString(KEY_MOOD, mood)
                .putBoolean(KEY_IS_OVER, isOver)
                .apply()

            val manager = AppWidgetManager.getInstance(context)
            val fullIds = manager.getAppWidgetIds(
                ComponentName(context, CatatimWidgetProvider::class.java),
            )
            if (fullIds.isNotEmpty()) {
                updateWidgets(context, manager, fullIds, defaultCompact = false)
            }
            val miniIds = manager.getAppWidgetIds(
                ComponentName(context, CatatimMiniWidgetProvider::class.java),
            )
            if (miniIds.isNotEmpty()) {
                updateWidgets(context, manager, miniIds, defaultCompact = true)
            }
        }
    }
}
