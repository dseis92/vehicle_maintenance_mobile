import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// Helper functions for reminder status calculation and display

class ReminderHelpers {
  /// Calculates the status of a reminder based on due date and odometer
  /// Returns: 'Overdue', 'Due soon', 'Upcoming', or 'Inactive'
  static String calculateStatus(
    Map<String, dynamic> reminder,
    Map<String, dynamic>? vehicle,
  ) {
    final isActive = (reminder['is_active'] as bool?) ?? true;
    if (!isActive) return 'Inactive';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final nextDateStr = reminder['next_due_date'] as String?;
    DateTime? nextDate;
    if (nextDateStr != null) {
      try {
        nextDate = DateTime.parse(nextDateStr);
      } catch (_) {
        // Invalid date format
      }
    }

    final nextOdo = reminder['next_due_odometer'] as num?;
    final vehicleOdo =
        vehicle != null ? vehicle['current_odometer'] as num? : null;

    bool overdue = false;
    bool soon = false;

    // Check date-based status
    if (nextDate != null) {
      final dDay = DateTime(nextDate.year, nextDate.month, nextDate.day);
      if (dDay.isBefore(today)) {
        overdue = true;
      } else if (dDay == today) {
        soon = true;
      }
    }

    // Check odometer-based status
    if (nextOdo != null && vehicleOdo != null) {
      final remaining = nextOdo - vehicleOdo;
      if (remaining < 0) {
        overdue = true;
      } else if (remaining <= AppThresholds.dueSoonMileageThreshold) {
        soon = true;
      }
    }

    if (overdue) return ReminderStatus.overdue;
    if (soon) return ReminderStatus.dueSoon;
    return ReminderStatus.upcoming;
  }

  /// Gets the background color for a reminder status
  static Color getStatusColor(String status) {
    return ReminderStatus.getColor(status);
  }

  /// Gets the text color for a reminder status
  static Color getStatusTextColor(String status) {
    return ReminderStatus.getTextColor(status);
  }

  /// Gets a user-friendly label for a reminder status
  static String getStatusLabel(String status) {
    return ReminderStatus.getLabel(status);
  }

  /// Calculates remaining mileage until a reminder is due
  /// Returns null if either value is not available
  static num? calculateRemainingMileage(
    Map<String, dynamic> reminder,
    Map<String, dynamic>? vehicle,
  ) {
    final nextOdo = reminder['next_due_odometer'] as num?;
    final vehicleOdo =
        vehicle != null ? vehicle['current_odometer'] as num? : null;

    if (nextOdo == null || vehicleOdo == null) return null;

    return nextOdo - vehicleOdo;
  }

  /// Calculates days until a reminder is due
  /// Returns null if date is not available
  /// Returns negative number if overdue
  static int? calculateDaysUntilDue(Map<String, dynamic> reminder) {
    final nextDateStr = reminder['next_due_date'] as String?;
    if (nextDateStr == null) return null;

    try {
      final nextDate = DateTime.parse(nextDateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dDay = DateTime(nextDate.year, nextDate.month, nextDate.day);

      return dDay.difference(today).inDays;
    } catch (_) {
      return null;
    }
  }

  /// Groups reminders by status
  static Map<String, List<Map<String, dynamic>>> groupByStatus(
    List<Map<String, dynamic>> reminders,
    Map<String, Map<String, dynamic>> vehiclesMap,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{
      ReminderStatus.overdue: [],
      ReminderStatus.dueSoon: [],
      ReminderStatus.upcoming: [],
    };

    for (final reminder in reminders) {
      final vehicleId = reminder['vehicle_id'] as String?;
      final vehicle = vehicleId != null ? vehiclesMap[vehicleId] : null;
      final status = calculateStatus(reminder, vehicle);

      if (grouped.containsKey(status)) {
        grouped[status]!.add(reminder);
      } else {
        // Handle 'Inactive' or any other status
        grouped.putIfAbsent(status, () => []).add(reminder);
      }
    }

    return grouped;
  }
}
