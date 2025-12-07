import '../constants/app_constants.dart';
import 'base_service.dart';

/// Service for managing maintenance reminders
class ReminderService extends BaseService {
  /// Fetches all reminders for the current user
  Future<List<Map<String, dynamic>>> getReminders() async {
    requireAuth();

    final response = await supabase
        .from(DbTables.reminders)
        .select()
        .eq('user_id', currentUserId!)
        .order('created_at');

    return List<Map<String, dynamic>>.from(response);
  }

  /// Fetches reminders for a specific vehicle
  Future<List<Map<String, dynamic>>> getRemindersForVehicle(
    String vehicleId,
  ) async {
    requireAuth();

    final response = await supabase
        .from(DbTables.reminders)
        .select()
        .eq('vehicle_id', vehicleId)
        .eq('user_id', currentUserId!)
        .order('created_at');

    return List<Map<String, dynamic>>.from(response);
  }

  /// Fetches a single reminder by ID
  Future<Map<String, dynamic>?> getReminder(String reminderId) async {
    requireAuth();

    final response = await supabase
        .from(DbTables.reminders)
        .select()
        .eq('id', reminderId)
        .eq('user_id', currentUserId!)
        .maybeSingle();

    return response;
  }

  /// Creates a new reminder
  Future<Map<String, dynamic>> createReminder({
    required String vehicleId,
    required String type,
    String? reminderType,
    String? nextDueDate,
    num? nextDueOdometer,
    num? intervalDays,
    num? intervalMiles,
    String? notes,
    bool isActive = true,
  }) async {
    requireAuth();

    final data = {
      'user_id': currentUserId,
      'vehicle_id': vehicleId,
      'type': type,
      'reminder_type': reminderType,
      'next_due_date': nextDueDate,
      'next_due_odometer': nextDueOdometer,
      'interval_days': intervalDays,
      'interval_miles': intervalMiles,
      'notes': notes,
      'is_active': isActive,
    };

    final response = await supabase
        .from(DbTables.reminders)
        .insert(data)
        .select()
        .single();

    return response;
  }

  /// Updates an existing reminder
  Future<Map<String, dynamic>> updateReminder(
    String reminderId,
    Map<String, dynamic> updates,
  ) async {
    requireAuth();

    final response = await supabase
        .from(DbTables.reminders)
        .update(updates)
        .eq('id', reminderId)
        .eq('user_id', currentUserId!)
        .select()
        .single();

    return response;
  }

  /// Marks a reminder as done and advances it by the interval
  Future<Map<String, dynamic>> markReminderDone(
    String reminderId,
  ) async {
    requireAuth();

    final reminder = await getReminder(reminderId);
    if (reminder == null) {
      throw Exception('Reminder not found');
    }

    final updates = <String, dynamic>{};

    // Advance date if we have interval_days and next_due_date
    final intervalDays = reminder['interval_days'] as num?;
    final nextDueDateStr = reminder['next_due_date'] as String?;

    if (intervalDays != null &&
        intervalDays > 0 &&
        nextDueDateStr != null) {
      try {
        final nextDueDate = DateTime.parse(nextDueDateStr);
        final newDueDate = nextDueDate.add(
          Duration(days: intervalDays.toInt()),
        );
        updates['next_due_date'] = newDueDate.toIso8601String();
      } catch (_) {
        // Invalid date format
      }
    }

    // Advance odometer if we have interval_miles and next_due_odometer
    final intervalMiles = reminder['interval_miles'] as num?;
    final nextDueOdometer = reminder['next_due_odometer'] as num?;

    if (intervalMiles != null &&
        intervalMiles > 0 &&
        nextDueOdometer != null) {
      updates['next_due_odometer'] = nextDueOdometer + intervalMiles;
    }

    if (updates.isEmpty) {
      // No intervals set, just return the reminder as-is
      return reminder;
    }

    return await updateReminder(reminderId, updates);
  }

  /// Deletes a reminder
  Future<void> deleteReminder(String reminderId) async {
    requireAuth();

    await supabase
        .from(DbTables.reminders)
        .delete()
        .eq('id', reminderId)
        .eq('user_id', currentUserId!);
  }

  /// Gets count of active reminders for the current user
  Future<int> getActiveReminderCount() async {
    requireAuth();

    final response = await supabase
        .from(DbTables.reminders)
        .select('id')
        .eq('user_id', currentUserId!)
        .eq('is_active', true);

    return response.length;
  }

  /// Toggles the active status of a reminder
  Future<Map<String, dynamic>> toggleReminderActive(
    String reminderId,
  ) async {
    requireAuth();

    final reminder = await getReminder(reminderId);
    if (reminder == null) {
      throw Exception('Reminder not found');
    }

    final isActive = (reminder['is_active'] as bool?) ?? true;
    return await updateReminder(reminderId, {'is_active': !isActive});
  }
}
