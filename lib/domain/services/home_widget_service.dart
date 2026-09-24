import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../models/workout_model.dart';

class HomeWidgetService {
  HomeWidgetService._();

  static const String appGroupId = 'group.com.ironlog.ironlog';

  /// Initializes home widget settings and registers click callbacks
  static Future<void> init() async {
    try {
      await HomeWidget.setAppGroupId(appGroupId);
    } catch (e) {
      debugPrint('HomeWidgetService init error: $e');
    }
  }

  /// Synchronizes all Android home screen widgets from current app state
  static Future<void> syncAllWidgets({
    WorkoutModel? currentWorkout,
    int streakDays = 0,
    int daysTrainedThisWeek = 0,
    bool isSessionActive = false,
    Duration? elapsedDuration,
    String? currentExerciseName,
    int? currentSetNumber,
    int? totalExerciseSets,
    double? totalVolumeKg,
  }) async {
    try {
      // 1. Sync Today's Workout Widget
      final isRest = currentWorkout?.isRestDay == true;
      final isFinished = currentWorkout?.endedAt != null;
      final title = isRest
          ? 'Rest & Recovery Day'
          : (currentWorkout?.title ?? 'Daily Workout');
      
      final exCount = currentWorkout?.exercises.length ?? 0;
      final setsCount = currentWorkout?.totalSetsCount ?? 0;
      final subtitle = isRest
          ? 'Muscle recovery & adaptation'
          : (isFinished
              ? 'Finished • $exCount exercises • $setsCount sets'
              : (exCount > 0 ? '$exCount exercises • $setsCount sets' : 'Tap to select exercises'));

      final status = isSessionActive
          ? 'Active Session'
          : (isFinished ? 'Completed' : (isRest ? 'Resting' : 'Ready to train'));

      final btnText = isSessionActive ? 'Resume' : (isFinished ? 'View' : 'Start');

      await HomeWidget.saveWidgetData<String>('today_workout_title', title);
      await HomeWidget.saveWidgetData<String>('today_workout_subtitle', subtitle);
      await HomeWidget.saveWidgetData<String>('today_streak', '🔥 $streakDays Days');
      await HomeWidget.saveWidgetData<String>('today_status', status);
      await HomeWidget.saveWidgetData<String>('today_btn_text', btnText);
      await HomeWidget.updateWidget(
        name: 'TodayWorkoutWidgetProvider',
        androidName: 'TodayWorkoutWidgetProvider',
      );

      // 2. Sync Streak & Week Widget
      await HomeWidget.saveWidgetData<String>('streak_count', '🔥 $streakDays');
      await HomeWidget.saveWidgetData<String>('streak_days_label', 'Days Consistent');
      await HomeWidget.saveWidgetData<String>('streak_week_summary', '$daysTrainedThisWeek of 7 days trained');
      await HomeWidget.updateWidget(
        name: 'StreakWidgetProvider',
        androidName: 'StreakWidgetProvider',
      );

      // 3. Sync Quick Log Shortcuts Widget
      await HomeWidget.updateWidget(
        name: 'QuickLogWidgetProvider',
        androidName: 'QuickLogWidgetProvider',
      );

      // 4. Sync Dynamic Live Workout Widget
      await HomeWidget.saveWidgetData<bool>('live_is_active', isSessionActive);
      await HomeWidget.saveWidgetData<String>(
        'live_exercise_name',
        isSessionActive
            ? (currentExerciseName ?? currentWorkout?.title ?? 'Active Session')
            : (isFinished ? 'Session Finished' : 'No Active Session'),
      );

      String liveDetails = 'Tap to plan your workout';
      if (isSessionActive) {
        if (currentSetNumber != null && totalExerciseSets != null) {
          liveDetails = 'Set $currentSetNumber of $totalExerciseSets in progress';
        } else {
          liveDetails = '$exCount exercises • $setsCount sets logged';
        }
      } else if (isFinished) {
        liveDetails = 'Saved to History • Well done!';
      }

      final timerStr = elapsedDuration != null
          ? _formatDuration(elapsedDuration)
          : '00:00';

      await HomeWidget.saveWidgetData<String>('live_details', liveDetails);
      await HomeWidget.saveWidgetData<String>('live_timer', timerStr);
      await HomeWidget.saveWidgetData<String>(
        'live_volume',
        totalVolumeKg != null && totalVolumeKg > 0
            ? 'Vol: ${totalVolumeKg.toStringAsFixed(0)} kg'
            : 'Vol: 0 kg',
      );
      await HomeWidget.saveWidgetData<String>(
        'live_status_label',
        isSessionActive ? 'LIVE WORKOUT' : (isFinished ? 'FINISHED' : 'SESSION IDLE'),
      );
      await HomeWidget.saveWidgetData<String>(
        'live_btn_text',
        isSessionActive ? 'Resume' : (isFinished ? 'Summary' : 'Start'),
      );

      await HomeWidget.updateWidget(
        name: 'LiveWorkoutWidgetProvider',
        androidName: 'LiveWorkoutWidgetProvider',
      );
    } catch (e) {
      debugPrint('HomeWidgetService.syncAllWidgets error: $e');
    }
  }

  static String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    final h = d.inHours;
    if (h > 0) {
      final remM = m % 60;
      return '$h:${remM.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
