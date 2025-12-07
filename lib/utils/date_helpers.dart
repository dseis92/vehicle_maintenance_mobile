import 'package:intl/intl.dart';

/// Date formatting and manipulation helpers

class DateHelpers {
  /// Formats an ISO date string to MM/DD/YYYY format
  /// Returns 'No date' if the input is null or invalid
  static String formatDate(String? isoString) {
    if (isoString == null) return 'No date';
    try {
      final d = DateTime.parse(isoString);
      return '${d.month}/${d.day}/${d.year}';
    } catch (_) {
      return 'Invalid date';
    }
  }

  /// Formats a DateTime object to MM/DD/YYYY format
  /// Returns 'Not set' if the input is null
  static String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'Not set';
    return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
  }

  /// Formats an ISO date string using a custom format pattern
  /// Returns 'No date' if the input is null or invalid
  static String formatDateCustom(String? isoString, String pattern) {
    if (isoString == null) return 'No date';
    try {
      final d = DateTime.parse(isoString);
      return DateFormat(pattern).format(d);
    } catch (_) {
      return 'Invalid date';
    }
  }

  /// Formats a DateTime object using a custom format pattern
  /// Returns 'Not set' if the input is null
  static String formatDateTimeCustom(DateTime? dateTime, String pattern) {
    if (dateTime == null) return 'Not set';
    return DateFormat(pattern).format(dateTime);
  }

  /// Returns a normalized date (midnight) for comparison purposes
  static DateTime normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Checks if a date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized == today;
  }

  /// Checks if a date is in the past
  static bool isPast(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.isBefore(today);
  }

  /// Calculates days between two dates
  static int daysBetween(DateTime from, DateTime to) {
    final fromNormalized = normalizeDate(from);
    final toNormalized = normalizeDate(to);
    return toNormalized.difference(fromNormalized).inDays;
  }
}
