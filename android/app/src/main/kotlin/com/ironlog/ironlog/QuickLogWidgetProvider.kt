package com.ironlog.ironlog

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class QuickLogWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_quick_log).apply {
                // Workout shortcut
                val workoutIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("ironlog://today")
                )
                setOnClickPendingIntent(R.id.widget_quick_workout, workoutIntent)

                // Nutrition shortcut
                val nutritionIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("ironlog://nutrition")
                )
                setOnClickPendingIntent(R.id.widget_quick_nutrition, nutritionIntent)

                // AI Coach shortcut
                val aiIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("ironlog://ai")
                )
                setOnClickPendingIntent(R.id.widget_quick_ai, aiIntent)
                setOnClickPendingIntent(R.id.widget_quick_container, workoutIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
