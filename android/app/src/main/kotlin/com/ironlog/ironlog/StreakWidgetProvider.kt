package com.ironlog.ironlog

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class StreakWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_streak).apply {
                val streakCount = widgetData.getString("streak_count", "🔥 0") ?: "🔥 0"
                val daysLabel = widgetData.getString("streak_days_label", "Days Consistent") ?: "Days Consistent"
                val weekSummary = widgetData.getString("streak_week_summary", "0 of 7 days trained") ?: "0 of 7 days trained"

                setTextViewText(R.id.widget_streak_count, streakCount)
                setTextViewText(R.id.widget_streak_days_label, daysLabel)
                setTextViewText(R.id.widget_streak_week_summary, weekSummary)

                val intent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("ironlog://history")
                )
                setOnClickPendingIntent(R.id.widget_streak_container, intent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
