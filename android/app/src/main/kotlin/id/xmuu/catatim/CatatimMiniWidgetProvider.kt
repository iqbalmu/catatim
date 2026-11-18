package id.xmuu.catatim

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.os.Bundle

/**
 * Widget home screen versi setengah layar (2×2): berbagi state & rendering
 * responsif dengan [CatatimWidgetProvider].
 */
class CatatimMiniWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        CatatimWidgetProvider.updateWidgets(
            context,
            appWidgetManager,
            appWidgetIds,
            defaultCompact = true,
        )
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        CatatimWidgetProvider.updateWidgets(
            context,
            appWidgetManager,
            intArrayOf(appWidgetId),
            defaultCompact = true,
        )
    }
}
