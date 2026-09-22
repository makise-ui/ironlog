import 'package:intl/intl.dart';

class AppDateUtils {
  AppDateUtils._();

  static final DateFormat _dayMonthYearFormat = DateFormat('EEE, MMM d, yyyy');
  static final DateFormat _shortDateFormat = DateFormat('MMM d');
  static final DateFormat _timeFormat = DateFormat('h:mm a');
  static final DateFormat _isoDayFormat = DateFormat('yyyy-MM-dd');

  static String formatFullDate(DateTime date) => _dayMonthYearFormat.format(date);
  static String formatShortDate(DateTime date) => _shortDateFormat.format(date);
  static String formatTime(DateTime date) => _timeFormat.format(date);
  static String toIsoDay(DateTime date) => _isoDayFormat.format(date);

  static DateTime normalizeDate(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day);
  }

  static bool isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  static bool isYesterday(DateTime dt) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day;
  }

  static String formatRelativeDate(DateTime dt) {
    if (isToday(dt)) return 'Today';
    if (isYesterday(dt)) return 'Yesterday';
    return _dayMonthYearFormat.format(dt);
  }

  /// Returns Monday of the week for a given date
  static DateTime startOfWeek(DateTime dt) {
    final normalized = normalizeDate(dt);
    // In Dart weekday 1 = Monday, 7 = Sunday
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  /// Returns Sunday of the week for a given date
  static DateTime endOfWeek(DateTime dt) {
    final start = startOfWeek(dt);
    return start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
  }

  /// Returns duration formatted as mm:ss or hh:mm:ss
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }
}
