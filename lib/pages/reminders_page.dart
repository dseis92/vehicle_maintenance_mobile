import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

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
  bool _loading = true;
  String? _errorText;
  List<Map<String, dynamic>> _reminders = [];

  // Add reminder form state
  String _reminderType = 'Oil change';
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
    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final vehicleId = widget.vehicle['id'] as String?;
      if (vehicleId == null) {
        setState(() {
          _errorText = 'Vehicle ID missing.';
          _reminders = [];
        });
        return;
      }

      final resp = await supabase
          .from('reminders')
          .select()
          .eq('vehicle_id', vehicleId)
          .order('next_due_date', ascending: true)
          .order('next_due_odometer', ascending: true)
          .order('created_at', ascending: true);

      final list =
          (resp as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

      setState(() {
        _reminders = list;
      });
    } on PostgrestException catch (e) {
      setState(() {
        _errorText = e.message;
        _reminders = [];
      });
    } catch (e) {
      setState(() {
        _errorText = 'Unexpected error: $e';
        _reminders = [];
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return 'No date set';
    try {
      final d = DateTime.parse(isoString);
      return '${d.month}/${d.day}/${d.year}';
    } catch (_) {
      return isoString;
    }
  }

  String _statusForReminder(Map<String, dynamic> r) {
    final isActive = (r['is_active'] as bool?) ?? true;
    if (!isActive) return 'Inactive';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final nextDateStr = r['next_due_date'] as String?;
    DateTime? nextDate;
    if (nextDateStr != null) {
      try {
        nextDate = DateTime.parse(nextDateStr);
      } catch (_) {}
    }

    final nextOdo = r['next_due_odometer'] as num?;
    final vehicleOdo = widget.vehicle['current_odometer'] as num?;

    bool overdue = false;
    bool todayOrSoon = false;

    // Date-based
    if (nextDate != null) {
      final dDay = DateTime(nextDate.year, nextDate.month, nextDate.day);
      if (dDay.isBefore(today)) {
        overdue = true;
      } else if (dDay == today) {
        todayOrSoon = true;
      }
    }

    // Mileage-based
    if (nextOdo != null && vehicleOdo != null) {
      final remaining = nextOdo - vehicleOdo;
      if (remaining < 0) {
        overdue = true;
      } else if (remaining <= 200) {
        todayOrSoon = true;
      }
    }

    if (overdue) return 'Overdue';
    if (todayOrSoon) return 'Due soon';
    return 'Upcoming';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Overdue':
        return Colors.red;
      case 'Due soon':
        return Colors.orange;
      case 'Inactive':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  void _showAddReminderDialog() {
    _reminderType = 'Oil change';
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
              dateLabel =
                  '${_dueDate!.month}/${_dueDate!.day}/${_dueDate!.year}';
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
                      items: const [
                        DropdownMenuItem(
                          value: 'Oil change',
                          child: Text('Oil change'),
                        ),
                        DropdownMenuItem(
                          value: 'Tire rotation',
                          child: Text('Tire rotation'),
                        ),
                        DropdownMenuItem(
                          value: 'Charge rotation',
                          child: Text('Charge rotation'),
                        ),
                        DropdownMenuItem(
                          value: 'Brake service',
                          child: Text('Brake service'),
                        ),
                        DropdownMenuItem(
                          value: 'Inspection',
                          child: Text('Inspection'),
                        ),
                        DropdownMenuItem(
                          value: 'Car wash / Detail',
                          child: Text('Car wash / Detail'),
                        ),
                        DropdownMenuItem(
                          value: 'Other',
                          child: Text('Other'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setLocalState(() {
                          _reminderType = v;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
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
                    const SizedBox(height: 8),
                    // Due odometer
                    TextField(
                      controller: _dueOdometerController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Next due odometer (optional)',
                        hintText: 'e.g. 102500',
                      ),
                    ),
                    const SizedBox(height: 8),
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
                        const SizedBox(width: 8),
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
                    const SizedBox(height: 8),
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
      setState(() {
        _errorText = 'Vehicle ID missing.';
      });
      return;
    }

    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        _errorText = 'No user logged in.';
      });
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
        setState(() {
          _errorText = 'Next due odometer must be a number.';
        });
        return;
      }
    }

    int? intervalDays;
    if (intervalDaysText.isNotEmpty) {
      intervalDays = int.tryParse(intervalDaysText);
      if (intervalDays == null) {
        setState(() {
          _errorText = 'Interval days must be a number.';
        });
        return;
      }
    }

    int? intervalMiles;
    if (intervalMilesText.isNotEmpty) {
      intervalMiles = int.tryParse(intervalMilesText);
      if (intervalMiles == null) {
        setState(() {
          _errorText = 'Interval miles must be a number.';
        });
        return;
      }
    }

    setState(() {
      _savingReminder = true;
      _errorText = null;
    });

    try {
      await supabase.from('reminders').insert({
        'user_id': user.id,
        'vehicle_id': vehicleId,
        // keep both for compatibility with web + new mobile
        'type': _reminderType,
        'reminder_type': _reminderType,
        'notes': notes.isNotEmpty ? notes : null,
        'next_due_date':
            _dueDate != null ? _dueDate!.toIso8601String() : null,
        'next_due_odometer': nextOdo,
        'interval_days': intervalDays,
        'interval_miles': intervalMiles,
        'is_active': true,
      });

      await _loadReminders();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on PostgrestException catch (e) {
      setState(() {
        _errorText = e.message;
      });
    } catch (e) {
      setState(() {
        _errorText = 'Unexpected error: $e';
      });
    } finally {
      setState(() {
        _savingReminder = false;
      });
    }
  }

  Future<void> _deleteReminder(String id) async {
    try {
      await supabase.from('reminders').delete().eq('id', id);
      await _loadReminders();
    } on PostgrestException catch (e) {
      setState(() {
        _errorText = e.message;
      });
    } catch (e) {
      setState(() {
        _errorText = 'Unexpected error: $e';
      });
    }
  }

  Future<void> _markReminderDone(Map<String, dynamic> r) async {
    final id = r['id'] as String?;
    if (id == null) return;

    final intervalDays = r['interval_days'] as int?;
    final intervalMiles = r['interval_miles'] as int?;
    final nextDateStr = r['next_due_date'] as String?;
    final nextOdo = r['next_due_odometer'] as int?;

    DateTime? newDate;
    int? newOdo;

    if (intervalDays != null && nextDateStr != null) {
      try {
        final current = DateTime.parse(nextDateStr);
        newDate = current.add(Duration(days: intervalDays));
      } catch (_) {}
    }

    if (intervalMiles != null && nextOdo != null) {
      newOdo = nextOdo + intervalMiles;
    }

    try {
      if (newDate != null || newOdo != null) {
        await supabase.from('reminders').update({
          'next_due_date': newDate?.toIso8601String(),
          'next_due_odometer': newOdo,
        }).eq('id', id);
      } else {
        await supabase
            .from('reminders')
            .update({'is_active': false}).eq('id', id);
      }
      await _loadReminders();
    } on PostgrestException catch (e) {
      setState(() {
        _errorText = e.message;
      });
    } catch (e) {
      setState(() {
        _errorText = 'Unexpected error: $e';
      });
    }
  }

  void _showReminderDetails(Map<String, dynamic> r) {
    final type =
        (r['reminder_type'] ?? r['type']) as String? ?? 'Reminder';
    final status = _statusForReminder(r);
    final statusColor = _statusColor(status);
    final nextDateStr = _formatDate(r['next_due_date'] as String?);
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
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: statusColor.withOpacity(0.12),
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
                const SizedBox(height: 8),
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
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 8),
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
        padding: EdgeInsets.all(12),
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
        final status = _statusForReminder(r);
        final statusColor = _statusColor(status);
        final nextDateStr = _formatDate(r['next_due_date'] as String?);
        final nextOdo = r['next_due_odometer'] as num?;

        String sub = 'Next date: $nextDateStr';
        if (nextOdo != null) {
          sub += ' • Next at ${nextOdo.toInt()}';
        }

        return InkWell(
          onTap: () => _showReminderDetails(r),
          borderRadius: BorderRadius.circular(12),
          child: Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Padding(
              padding: const EdgeInsets.all(12),
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
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: statusColor.withOpacity(0.12),
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
                  padding: const EdgeInsets.all(12),
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
