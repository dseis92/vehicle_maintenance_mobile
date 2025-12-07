import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../services/auth_service.dart';
import '../services/vehicle_service.dart';
import '../services/reminder_service.dart';
import '../utils/date_helpers.dart';
import '../utils/reminder_helpers.dart';
import '../utils/validation_helpers.dart';

/// Per-vehicle reminders page.
/// Lets you:
/// - View all reminders for this vehicle
/// - Add a new reminder (with Charge rotation type)
/// - Mark reminder as done (advance if interval set, otherwise deactivate)
/// - Delete reminder
class RemindersPage extends StatefulWidget {
  final Map<String, dynamic> vehicle;

  const RemindersPage({super.key, required this.vehicle});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  final _authService = AuthService();
  final _vehicleService = VehicleService();
  final _reminderService = ReminderService();

  bool _loading = true;
  String? _errorText;
  List<Map<String, dynamic>> _reminders = [];

  // Add reminder form state
  String _reminderType = MaintenanceCategories.oilChange;
  DateTime? _dueDate = DateTime.now();
  final TextEditingController _dueOdometerController =
      TextEditingController();
  final TextEditingController _intervalDaysController =
      TextEditingController();
  final TextEditingController _intervalMilesController =
      TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _savingReminder = false;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  @override
  void dispose() {
    _dueOdometerController.dispose();
    _intervalDaysController.dispose();
    _intervalMilesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadReminders() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorText = null;
      });
    }

    try {
      final vehicleId = widget.vehicle['id'] as String?;
      if (vehicleId == null) {
        if (mounted) {
          setState(() {
            _errorText = 'Vehicle ID missing.';
            _reminders = [];
          });
        }
        return;
      }

      final reminders =
          await _reminderService.getRemindersForVehicle(vehicleId);

      if (mounted) {
        setState(() {
          _reminders = reminders;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = 'Error loading reminders: $e';
          _reminders = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _showAddReminderDialog() {
    _reminderType = MaintenanceCategories.oilChange;
    _dueDate = DateTime.now();
    _dueOdometerController.text = '';
    _intervalDaysController.text = '';
    _intervalMilesController.text = '';
    _notesController.text = '';
    _savingReminder = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            Future<void> pickDueDate() async {
              final initial = _dueDate ?? DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: initial,
                firstDate: DateTime(1990),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setLocalState(() {
                  _dueDate = picked;
                });
              }
            }

            String dateLabel;
            if (_dueDate != null) {
              dateLabel = DateHelpers.formatDateTime(_dueDate);
            } else {
              dateLabel = 'No date';
            }

            return AlertDialog(
              title: const Text('Add reminder'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _reminderType,
                      decoration: const InputDecoration(
                        labelText: 'Reminder type',
                      ),
                      items: MaintenanceCategories.getDropdownItems(),
                      onChanged: (v) {
                        if (v == null) return;
                        setLocalState(() {
                          _reminderType = v;
                        });
                      },
                    ),
                    const SizedBox(height: UiConstants.spacingSmall),
                    // Due date
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Next due date (optional)',
                        style: TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        dateLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: pickDueDate,
                      ),
                    ),
                    const SizedBox(height: UiConstants.spacingSmall),
                    // Due odometer
                    TextField(
                      controller: _dueOdometerController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Next due odometer (optional)',
                        hintText: 'e.g. 102500',
                      ),
                    ),
                    const SizedBox(height: UiConstants.spacingSmall),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _intervalDaysController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Repeat every X days',
                            ),
                          ),
                        ),
                        const SizedBox(width: UiConstants.spacingSmall),
                        Expanded(
                          child: TextField(
                            controller: _intervalMilesController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Repeat every X miles',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: UiConstants.spacingSmall),
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _savingReminder
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: _savingReminder ? null : _saveReminder,
                  child: _savingReminder
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveReminder() async {
    final vehicleId = widget.vehicle['id'] as String?;
    if (vehicleId == null) {
      if (mounted) {
        setState(() {
          _errorText = 'Vehicle ID missing.';
        });
      }
      return;
    }

    final user = _authService.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _errorText = 'No user logged in.';
        });
      }
      return;
    }

    final dueOdoText = _dueOdometerController.text.trim();
    final intervalDaysText = _intervalDaysController.text.trim();
    final intervalMilesText = _intervalMilesController.text.trim();
    final notes = _notesController.text.trim();

    int? nextOdo;
    if (dueOdoText.isNotEmpty) {
      nextOdo = int.tryParse(dueOdoText.replaceAll(',', ''));
      if (nextOdo == null) {
        if (mounted) {
          setState(() {
            _errorText = 'Next due odometer must be a number.';
          });
        }
        return;
      }
    }

    int? intervalDays;
    if (intervalDaysText.isNotEmpty) {
      intervalDays = int.tryParse(intervalDaysText);
      if (intervalDays == null) {
        if (mounted) {
          setState(() {
            _errorText = 'Interval days must be a number.';
          });
        }
        return;
      }
    }

    int? intervalMiles;
    if (intervalMilesText.isNotEmpty) {
      intervalMiles = int.tryParse(intervalMilesText);
      if (intervalMiles == null) {
        if (mounted) {
          setState(() {
            _errorText = 'Interval miles must be a number.';
          });
        }
        return;
      }
    }

    if (mounted) {
      setState(() {
        _savingReminder = true;
        _errorText = null;
      });
    }

    try {
      await _reminderService.createReminder(
        vehicleId: vehicleId,
        type: _reminderType,
        reminderType: _reminderType,
        nextDueDate: _dueDate?.toIso8601String(),
        nextDueOdometer: nextOdo,
        intervalDays: intervalDays,
        intervalMiles: intervalMiles,
        notes: notes.isNotEmpty ? notes : null,
        isActive: true,
      );

      await _loadReminders();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = 'Error saving reminder: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _savingReminder = false;
        });
      }
    }
  }

  Future<void> _deleteReminder(String id) async {
    try {
      await _reminderService.deleteReminder(id);
      await _loadReminders();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = 'Error deleting reminder: $e';
        });
      }
    }
  }

  Future<void> _markReminderDone(Map<String, dynamic> r) async {
    final id = r['id'] as String?;
    if (id == null) return;

    final intervalDays = r['interval_days'] as num?;
    final intervalMiles = r['interval_miles'] as num?;

    try {
      // If no intervals are set, deactivate the reminder
      if ((intervalDays == null || intervalDays <= 0) &&
          (intervalMiles == null || intervalMiles <= 0)) {
        await _reminderService.updateReminder(id, {'is_active': false});
      } else {
        // Otherwise, use the service to advance the reminder
        await _reminderService.markReminderDone(id);
      }
      await _loadReminders();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = 'Error marking reminder as done: $e';
        });
      }
    }
  }

  void _showReminderDetails(Map<String, dynamic> r) {
    final type =
        (r['reminder_type'] ?? r['type']) as String? ?? 'Reminder';
    final status = ReminderHelpers.calculateStatus(r, widget.vehicle);
    final statusColor = ReminderHelpers.getStatusColor(status);
    final nextDateStr = DateHelpers.formatDate(r['next_due_date'] as String?);
    final nextOdo = r['next_due_odometer'] as num?;
    final notes = r['notes'] as String?;
    final intervalDays = r['interval_days'] as int?;
    final intervalMiles = r['interval_miles'] as int?;
    final id = r['id'] as String?;

    String nextOdoText = 'No mileage due set';
    if (nextOdo != null) {
      nextOdoText = 'Next due at ${nextOdo.toInt()}';
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(type),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: UiConstants.spacingSmall,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: statusColor.withValues(alpha: 0.12),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 11,
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: UiConstants.spacingSmall),
                Text(
                  'Next due date: $nextDateStr',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  nextOdoText,
                  style: const TextStyle(fontSize: 13),
                ),
                if (intervalDays != null || intervalMiles != null) ...[
                  const SizedBox(height: UiConstants.spacingSmall),
                  const Text(
                    'Repeats:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (intervalDays != null)
                    Text(
                      'Every $intervalDays days',
                      style: const TextStyle(fontSize: 13),
                    ),
                  if (intervalMiles != null)
                    Text(
                      'Every $intervalMiles miles',
                      style: const TextStyle(fontSize: 13),
                    ),
                ],
                if (notes != null && notes.isNotEmpty) ...[
                  const SizedBox(height: UiConstants.spacingSmall),
                  const Text(
                    'Notes:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notes,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (id != null) ...[
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _markReminderDone(r);
                },
                child: const Text('Mark done'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('Delete reminder?'),
                        content: const Text(
                          'This cannot be undone.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () =>
                                Navigator.of(context).pop(true),
                            child: const Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                  if (confirm == true) {
                    await _deleteReminder(id);
                  }
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildReminderList() {
    if (_reminders.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(UiConstants.spacingMedium),
        child: Text(
          'No reminders yet. Add your first reminder to stay ahead of maintenance.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey,
          ),
        ),
      );
    }

    return Column(
      children: _reminders.map((r) {
        final type =
            (r['reminder_type'] ?? r['type']) as String? ?? 'Reminder';
        final status = ReminderHelpers.calculateStatus(r, widget.vehicle);
        final statusColor = ReminderHelpers.getStatusColor(status);
        final nextDateStr = DateHelpers.formatDate(r['next_due_date'] as String?);
        final nextOdo = r['next_due_odometer'] as num?;

        String sub = 'Next date: $nextDateStr';
        if (nextOdo != null) {
          sub += ' • Next at ${nextOdo.toInt()}';
        }

        return InkWell(
          onTap: () => _showReminderDetails(r),
          borderRadius: BorderRadius.circular(UiConstants.borderRadiusMedium),
          child: Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(UiConstants.borderRadiusMedium),
            ),
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Padding(
              padding: const EdgeInsets.all(UiConstants.spacingMedium),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sub,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: UiConstants.spacingSmall),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: UiConstants.spacingSmall,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: statusColor.withValues(alpha: 0.12),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.vehicle['name'] as String? ?? 'Vehicle';

    return Scaffold(
      appBar: AppBar(
        title: Text('$name reminders'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadReminders,
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(UiConstants.spacingMedium),
                  children: [
                    if (_errorText != null) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Text(
                          _errorText!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                    Row(
                      children: [
                        const Text(
                          'Reminders',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _showAddReminderDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _buildReminderList(),
                  ],
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddReminderDialog,
        icon: const Icon(Icons.add_alert),
        label: const Text('Add reminder'),
      ),
    );
  }
}
