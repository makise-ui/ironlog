import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import '../../data/repositories/workout_repository.dart';

class AppNotificationService with WidgetsBindingObserver {
  static final AppNotificationService instance = AppNotificationService._();
  AppNotificationService._();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool isAppInBackground = false;

  static const int _aiTaskNotificationId = 1002;
  static const int _aiSuggestionNotificationId = 1003;
  static const int _dailyCoachScheduleId = 2001;

  static const String _aiChannelId = 'ai_workout_channel';
  static const String _aiChannelName = 'AI Workout Coach';
  static const String _aiChannelDesc = 'Alerts when AI finishes workout plans, analysis or answers';

  static const String _suggestionsChannelId = 'ai_suggestions_channel';
  static const String _suggestionsChannelName = 'AI Coaching Suggestions';
  static const String _suggestionsChannelDesc = 'Smart workout tips, streak preservation, and recovery advice';

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      tz.initializeTimeZones();
    } catch (e) {
      debugPrint('Timezone initialization note: $e');
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    try {
      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('Notification tapped with payload: ${response.payload}');
        },
      );
      _initialized = true;

      // Register lifecycle observer to track whether app is currently active or in background
      WidgetsBinding.instance.addObserver(this);
    } catch (e) {
      debugPrint('NotificationService init warning: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    isAppInBackground = state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden;
  }

  Future<void> requestPermissions() async {
    try {
      final androidPlatform = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlatform != null) {
        await androidPlatform.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('Notification permission error: $e');
    }
  }

  /// Shows an ongoing progress notification while the AI is analyzing/executing in the background
  Future<void> showAiRunningNotification({required String prompt}) async {
    if (!_initialized) return;

    try {
      final androidDetails = AndroidNotificationDetails(
        _aiChannelId,
        _aiChannelName,
        channelDescription: _aiChannelDesc,
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        showWhen: true,
        styleInformation: BigTextStyleInformation(
          'Processing: "$prompt"',
          contentTitle: 'AI Coach Working...',
        ),
      );

      final details = NotificationDetails(android: androidDetails);
      await _notifications.show(
        _aiTaskNotificationId,
        'AI Coach Working...',
        'Processing: "$prompt"',
        details,
      );
    } catch (e) {
      debugPrint('Error showing AI running notification: $e');
    }
  }

  /// Shows a notification when the AI has finished its response or tool executions
  Future<void> showAiCompletedNotification({
    required String prompt,
    required String snippet,
    bool force = false,
  }) async {
    if (!_initialized) return;

    // Show if forced, or if the user minimized the app
    if (!force && !isAppInBackground) {
      // If user is directly in app looking at it, dismiss the ongoing notification
      await cancelNotification(_aiTaskNotificationId);
      return;
    }

    try {
      final cleanSnippet = snippet.isEmpty ? 'Your AI Coach finished processing your request.' : snippet;
      final androidDetails = AndroidNotificationDetails(
        _aiChannelId,
        _aiChannelName,
        channelDescription: _aiChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        autoCancel: true,
        ongoing: false,
        styleInformation: BigTextStyleInformation(
          cleanSnippet,
          contentTitle: 'AI Workout Coach Ready',
          summaryText: prompt.length > 25 ? '${prompt.substring(0, 22)}...' : prompt,
        ),
      );

      final details = NotificationDetails(android: androidDetails);
      await _notifications.show(
        _aiTaskNotificationId,
        'AI Workout Coach Ready',
        cleanSnippet,
        details,
        payload: '/ai',
      );
    } catch (e) {
      debugPrint('Error showing AI completed notification: $e');
    }
  }

  /// Shows an immediate smart AI coaching suggestion notification
  Future<void> showAiSuggestionNotification({
    required String title,
    required String body,
  }) async {
    if (!_initialized) return;

    try {
      final androidDetails = AndroidNotificationDetails(
        _suggestionsChannelId,
        _suggestionsChannelName,
        channelDescription: _suggestionsChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        autoCancel: true,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
        ),
      );

      final details = NotificationDetails(android: androidDetails);
      await _notifications.show(
        _aiSuggestionNotificationId,
        title,
        body,
        details,
        payload: '/today',
      );
    } catch (e) {
      debugPrint('Error showing AI suggestion notification: $e');
    }
  }

  /// Sends a dynamic, context-aware suggestion based on streak and workout history
  Future<void> sendContextualAiSuggestion(WorkoutRepository workoutRepo) async {
    try {
      final streakData = await workoutRepo.getStreakAndWeekData();
      final todayWorkout = await workoutRepo.getOrCreateTodayWorkout();
      final hasLiftedToday = todayWorkout.exercises.any(
        (e) => e.sets.any((s) => !s.archived && (s.reps > 0 || s.weight > 0)),
      );
      final isRestToday = todayWorkout.title.toLowerCase().contains('rest');

      String title;
      String body;

      if (hasLiftedToday) {
        title = 'Session Crushed Today!';
        body = 'Great work completing your sets. Don\'t forget proper post-workout nutrition and hydration for optimal recovery!';
      } else if (isRestToday) {
        title = 'Active Recovery Mode';
        body = 'Your ${streakData.streakDays}-day streak is secured! Take time to stretch, hydrate, and prep for your next training session.';
      } else if (streakData.streakDays > 0) {
        title = 'Keep Your ${streakData.streakDays}-Day Streak Alive!';
        body = 'You have logged ${streakData.workoutsThisWeek} sessions this week. Ready to get today\'s workout in?';
      } else {
        final tips = [
          'Progressive Overload Tip: Aim to add 1 rep or small weight increments to your working sets today!',
          'Mind-Muscle Connection: Focus on slow, controlled eccentrics on your compound lifts.',
          'Ready to lift? Your AI Coach is standing by to recommend optimal working weights.',
          'Consistency is key: Even a 30-minute focused session compounds into huge long-term gains.',
        ];
        final randomTip = tips[math.Random().nextInt(tips.length)];
        title = 'AI Coach Suggestion';
        body = randomTip;
      }

      await showAiSuggestionNotification(title: title, body: body);
    } catch (e) {
      debugPrint('Error sending contextual suggestion: $e');
      await showAiSuggestionNotification(
        title: 'AI Coach Motivation',
        body: 'Consistency creates champions! Ready to log your session today?',
      );
    }
  }

  /// Schedule periodic daily coach suggestions
  Future<void> scheduleDailyCoachSuggestion() async {
    if (!_initialized) return;

    try {
      final androidDetails = AndroidNotificationDetails(
        _suggestionsChannelId,
        _suggestionsChannelName,
        channelDescription: _suggestionsChannelDesc,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );

      final details = NotificationDetails(android: androidDetails);

      // Periodically trigger a daily motivational check-in
      await _notifications.periodicallyShow(
        _dailyCoachScheduleId,
        'Daily AI Coach Briefing',
        'Check in with your AI Coach for today\'s workout recommendations and recovery metrics!',
        RepeatInterval.daily,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: '/today',
      );
    } catch (e) {
      debugPrint('Error scheduling daily coach suggestion: $e');
    }
  }

  Future<void> cancelDailyCoachSuggestion() async {
    if (!_initialized) return;
    try {
      await _notifications.cancel(_dailyCoachScheduleId);
    } catch (_) {}
  }

  Future<void> cancelNotification(int id) async {
    if (!_initialized) return;
    try {
      await _notifications.cancel(id);
    } catch (_) {}
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}
