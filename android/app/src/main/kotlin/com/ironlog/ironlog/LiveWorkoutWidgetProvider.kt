package com.ironlog.ironlog

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class LiveWorkoutWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_live_workout).apply {
                val isActive = widgetData.getBoolean("live_is_active", false)
                val exerciseName = widgetData.getString("live_exercise_name", if (isActive) "Active Workout" else "No Active Session") ?: "No Active Session"
                val details = widgetData.getString("live_details", if (isActive) "Session in progress" else "Tap to plan your workout") ?: "Tap to plan your workout"
                val timerText = widgetData.getString("live_timer", "00:00") ?: "00:00"
                val volumeText = widgetData.getString("live_volume", "Vol: 0 kg") ?: "Vol: 0 kg"
                val statusLabel = widgetData.getString("live_status_label", if (isActive) "LIVE WORKOUT" else "SESSION IDLE") ?: "SESSION IDLE"
                val btnText = widgetData.getString("live_btn_text", if (isActive) "Resume" else "Start") ?: "Resume"

                setTextViewText(R.id.widget_live_exercise, exerciseName)
                setTextViewText(R.id.widget_live_details, details)
                setTextViewText(R.id.widget_live_timer, timerText)
                setTextViewText(R.id.widget_live_volume, volumeText)
                setTextViewText(R.id.widget_live_status_label, statusLabel)
                setTextViewText(R.id.widget_live_btn, btnText)

                val intent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("ironlog://today")
                )
                setOnClickPendingIntent(R.id.widget_live_container, intent)
                setOnClickPendingIntent(R.id.widget_live_btn, intent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
