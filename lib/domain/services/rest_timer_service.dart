import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class RestTimerState {
  final DateTime? endsAt;
  final int totalDurationSeconds;
  final String exerciseName;
  final bool isPaused;
  final int? pausedRemainingSeconds;

  const RestTimerState({
    this.endsAt,
    this.totalDurationSeconds = 90,
    this.exerciseName = '',
    this.isPaused = false,
    this.pausedRemainingSeconds,
  });

  bool get isActive => endsAt != null || isPaused;

  int get remainingSeconds {
    if (isPaused) {
      return pausedRemainingSeconds ?? 0;
    }
    if (endsAt == null) return 0;
    final diff = endsAt!.difference(DateTime.now()).inSeconds;
    return math.max(0, diff);
  }

  double get progress {
    if (totalDurationSeconds <= 0) return 1.0;
    final rem = remainingSeconds;
    return math.min(1.0, math.max(0.0, 1.0 - (rem / totalDurationSeconds)));
  }

  RestTimerState copyWith({
    DateTime? endsAt,
    int? totalDurationSeconds,
    String? exerciseName,
    bool? isPaused,
    int? pausedRemainingSeconds,
    bool clearEndsAt = false,
  }) {
    return RestTimerState(
      endsAt: clearEndsAt ? null : (endsAt ?? this.endsAt),
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      exerciseName: exerciseName ?? this.exerciseName,
      isPaused: isPaused ?? this.isPaused,
      pausedRemainingSeconds: pausedRemainingSeconds ?? this.pausedRemainingSeconds,
    );
  }
}

class RestTimerService extends ChangeNotifier with WidgetsBindingObserver {
  static final RestTimerService instance = RestTimerService._();
  RestTimerService._();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  Timer? _ticker;
  RestTimerState _state = const RestTimerState();
  bool _isAppInBackground = false;

  RestTimerState get state => _state;
  bool get isAppInBackground => _isAppInBackground;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    try {
      await _notifications.initialize(initSettings);
      _initialized = true;
      WidgetsBinding.instance.addObserver(this);
    } catch (e) {
      debugPrint('Notification init warning: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppInBackground = state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden;

    if (_isAppInBackground) {
      // If user minimized or switched away while resting, show status notification
      if (_state.isActive && _state.endsAt != null && !_state.isPaused) {
        _showBackgroundNotification(_state.endsAt!, _state.exerciseName);
      }
    } else if (state == AppLifecycleState.resumed) {
      // When user is back inside the app, suppress system notification
      _cancelNotification();
    }
  }

  Future<void> requestPermissions() async {
    try {
      final androidPlatform = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlatform != null) {
        await androidPlatform.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('Permission request error: $e');
    }
  }

  void start({required int seconds, required String exerciseName}) {
    _ticker?.cancel();
    final endsAt = DateTime.now().add(Duration(seconds: seconds));

    _state = RestTimerState(
      endsAt: endsAt,
      totalDurationSeconds: seconds,
      exerciseName: exerciseName,
      isPaused: false,
    );

    // Never trigger a push notification when the user is inside the app logging sets.
    // The in-app overlay handles the timer visually without interruptions.
    if (_isAppInBackground) {
      _showBackgroundNotification(endsAt, exerciseName);
    } else {
      _cancelNotification();
    }

    _startTicker();
    notifyListeners();
  }

  void addSeconds(int delta) {
    if (_state.endsAt == null && !_state.isPaused) return;

    if (_state.isPaused) {
      final newRemaining = math.max(5, (_state.pausedRemainingSeconds ?? 0) + delta);
      _state = _state.copyWith(
        pausedRemainingSeconds: newRemaining,
        totalDurationSeconds: math.max(_state.totalDurationSeconds, newRemaining),
      );
    } else {
      final currentRemaining = _state.remainingSeconds;
      final newRemaining = math.max(5, currentRemaining + delta);
      final newEndsAt = DateTime.now().add(Duration(seconds: newRemaining));

      _state = _state.copyWith(
        endsAt: newEndsAt,
        totalDurationSeconds: math.max(_state.totalDurationSeconds, newRemaining),
      );
      if (_isAppInBackground) {
        _showBackgroundNotification(newEndsAt, _state.exerciseName);
      }
    }

    notifyListeners();
  }

  void pause() {
    if (_state.endsAt == null || _state.isPaused) return;
    final remaining = _state.remainingSeconds;
    _cancelNotification();
    _ticker?.cancel();

    _state = _state.copyWith(
      isPaused: true,
      pausedRemainingSeconds: remaining,
      clearEndsAt: true,
    );
    notifyListeners();
  }

  void resume() {
    if (!_state.isPaused) return;
    final remaining = _state.pausedRemainingSeconds ?? 0;
    if (remaining <= 0) {
      stop();
      return;
    }

    final newEndsAt = DateTime.now().add(Duration(seconds: remaining));
    _state = _state.copyWith(
      endsAt: newEndsAt,
      isPaused: false,
      pausedRemainingSeconds: null,
    );

    if (_isAppInBackground) {
      _showBackgroundNotification(newEndsAt, _state.exerciseName);
    }
    _startTicker();
    notifyListeners();
  }

  void stop() {
    _cancelNotification();
    _ticker?.cancel();
    _state = const RestTimerState();
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_state.endsAt != null) {
        if (_state.endsAt!.isBefore(DateTime.now())) {
          final finishedEx = _state.exerciseName;
          stop();
          if (_isAppInBackground) {
            _showRestFinishedNotification(finishedEx);
          }
        } else {
          notifyListeners();
        }
      }
    });
  }

  Future<void> _showBackgroundNotification(DateTime endsAt, String exerciseName) async {
    if (!_initialized) return;

    try {
      final name = exerciseName.isEmpty ? 'Exercise' : exerciseName;
      final timeStr = '${endsAt.hour}:${endsAt.minute.toString().padLeft(2, '0')}';
      const androidDetails = AndroidNotificationDetails(
        'rest_timer_channel',
        'Rest Timer',
        channelDescription: 'Alerts when your rest interval is complete',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        showWhen: true,
      );
      const notificationDetails = NotificationDetails(android: androidDetails);

      await _notifications.show(
        1001,
        'Resting for $name',
        'Timer finishes at $timeStr',
        notificationDetails,
      );
    } catch (e) {
      debugPrint('Background notification error: $e');
    }
  }

  Future<void> _showRestFinishedNotification(String exerciseName) async {
    if (!_initialized) return;

    try {
      final name = exerciseName.isEmpty ? 'Your rest interval' : 'Rest for $exerciseName';
      const androidDetails = AndroidNotificationDetails(
        'rest_timer_channel',
        'Rest Timer',
        channelDescription: 'Alerts when your rest interval is complete',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        autoCancel: true,
      );
      const notificationDetails = NotificationDetails(android: androidDetails);

      await _notifications.show(
        1001,
        'Rest Complete!',
        '$name is finished. Time for your next set!',
        notificationDetails,
      );
    } catch (e) {
      debugPrint('Rest finished notification error: $e');
    }
  }

  Future<void> _cancelNotification() async {
    if (!_initialized) return;
    try {
      await _notifications.cancel(1001);
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }
}
