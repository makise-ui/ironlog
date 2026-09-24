package com.ironlog.ironlog

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class TodayWorkoutWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_today_workout).apply {
                val title = widgetData.getString("today_workout_title", "Today's Session") ?: "Today's Session"
                val subtitle = widgetData.getString("today_workout_subtitle", "Tap to plan your workout") ?: "Tap to plan your workout"
                val streak = widgetData.getString("today_streak", "🔥 0 Days") ?: "🔥 0 Days"
                val status = widgetData.getString("today_status", "Ready to train") ?: "Ready to train"
                val btnText = widgetData.getString("today_btn_text", "Open Session") ?: "Open Session"

                setTextViewText(R.id.widget_today_title, title)
                setTextViewText(R.id.widget_today_subtitle, subtitle)
                setTextViewText(R.id.widget_today_streak, streak)
                setTextViewText(R.id.widget_today_status, status)
                setTextViewText(R.id.widget_today_btn, btnText)

                // Launch IronLog deep link
                val intent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("ironlog://today")
                )
                setOnClickPendingIntent(R.id.widget_today_container, intent)
                setOnClickPendingIntent(R.id.widget_today_btn, intent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
