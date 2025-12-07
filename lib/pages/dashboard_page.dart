import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'vehicle_details_page.dart';
import 'reminders_page.dart';

final supabase = Supabase.instance.client;

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _loading = true;
  String? _errorText;

  int _vehicleCount = 0;
  int _activeRemindersCount = 0;
  int _overdueCount = 0;
  int _dueSoonCount = 0;

  // IoT summary
  int _vehiclesWithDevices = 0;
  int _staleDevices = 0;

  // Each item: { 'reminder': Map<String,dynamic>, 'vehicle': Map<String,dynamic>? }
  List<Map<String, dynamic>> _overdueReminders = [];
  List<Map<String, dynamic>> _dueSoonReminders = [];
  List<Map<String, dynamic>> _upcomingReminders = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _errorText = null;
      _overdueReminders = [];
      _dueSoonReminders = [];
      _upcomingReminders = [];
      _vehiclesWithDevices = 0;
      _staleDevices = 0;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _errorText = 'No user logged in.';
        });
        return;
      }

      // ---- Load vehicles ----
      final vehiclesResp = await supabase
          .from('vehicles')
          .select()
          .eq('user_id', user.id);

      final vehiclesList =
          (vehiclesResp as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      _vehicleCount = vehiclesList.length;

      final Map<String, Map<String, dynamic>> vehiclesById = {};
      for (final v in vehiclesList) {
        final id = v['id'] as String?;
        if (id != null) {
          vehiclesById[id] = v;
        }
      }

      // ---- Load active reminders ----
      final remindersResp = await supabase
          .from('reminders')
          .select(
            'id, user_id, vehicle_id, type, reminder_type, next_due_date, next_due_odometer, interval_days, interval_miles, is_active',
          )
          .eq('user_id', user.id)
          .eq('is_active', true);

      final remindersList =
          (remindersResp as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      _activeRemindersCount = remindersList.length;

      // ---- Classify reminders: Overdue / Due soon / Upcoming ----
      _overdueReminders = [];
      _dueSoonReminders = [];
      _upcomingReminders = [];

      for (final r in remindersList) {
        final vehicleId = r['vehicle_id'] as String?;
        final vehicle = vehicleId != null ? vehiclesById[vehicleId] : null;

        final status = _statusForReminder(r, vehicle);
        final item = {
          'reminder': r,
          'vehicle': vehicle,
        };

        if (status == 'Overdue') {
          _overdueReminders.add(item);
        } else if (status == 'Due soon') {
          _dueSoonReminders.add(item);
        } else if (status == 'Upcoming') {
          _upcomingReminders.add(item);
        }
      }

      _overdueCount = _overdueReminders.length;
      _dueSoonCount = _dueSoonReminders.length;

      // ---- IoT summary: vehicles with devices & stale devices ----
      await _loadIoTSummary(user.id);
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
        _loading = false;
      });
    }
  }

  Future<void> _loadIoTSummary(String userId) async {
    // Get all device links for this user
    final linksResp = await supabase
        .from('device_links')
        .select('vehicle_id, device_id')
        .eq('user_id', userId);

    final linksList =
        (linksResp as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    if (linksList.isEmpty) {
      setState(() {
        _vehiclesWithDevices = 0;
        _staleDevices = 0;
      });
      return;
    }

    // Count distinct vehicles with at least one device
    final vehicleIds = <String>{};
    final deviceIds = <String>{};
    for (final l in linksList) {
      final vId = l['vehicle_id'] as String?;
      final dId = l['device_id'] as String?;
      if (vId != null) vehicleIds.add(vId);
      if (dId != null) deviceIds.add(dId);
    }

    final now = DateTime.now().toUtc();
    final cutoff = now.subtract(const Duration(hours: 24));

    // For stale detection: check last telemetry per device
    int staleCount = 0;
    for (final dId in deviceIds) {
      final telemetryResp = await supabase
          .from('telemetry_events')
          .select('recorded_at')
          .eq('user_id', userId)
          .eq('device_id', dId)
          .order('recorded_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (telemetryResp == null) {
        // No telemetry at all -> stale
        staleCount++;
        continue;
      }

      final recordedAtStr = telemetryResp['recorded_at'] as String?;
      if (recordedAtStr == null) {
        staleCount++;
        continue;
      }

      try {
        final recordedAt = DateTime.parse(recordedAtStr).toUtc();
        if (recordedAt.isBefore(cutoff)) {
          staleCount++;
        }
      } catch (_) {
        staleCount++;
      }
    }

    setState(() {
      _vehiclesWithDevices = vehicleIds.length;
      _staleDevices = staleCount;
    });
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return 'No date';
    try {
      final d = DateTime.parse(isoString);
      return '${d.month}/${d.day}/${d.year}';
    } catch (_) {
      return isoString;
    }
  }

  String _statusForReminder(
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
      } catch (_) {}
    }

    final nextOdo = reminder['next_due_odometer'] as num?;
    final vehicleOdo =
        vehicle != null ? vehicle['current_odometer'] as num? : null;

    bool overdue = false;
    bool soon = false;

    if (nextDate != null) {
      final dDay = DateTime(nextDate.year, nextDate.month, nextDate.day);
      if (dDay.isBefore(today)) {
        overdue = true;
      } else if (dDay == today) {
        soon = true;
      }
    }

    if (nextOdo != null && vehicleOdo != null) {
      final remaining = nextOdo - vehicleOdo;
      if (remaining < 0) {
        overdue = true;
      } else if (remaining <= 200) {
        soon = true;
      }
    }

    if (overdue) return 'Overdue';
    if (soon) return 'Due soon';
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

  String _vehicleTitle(Map<String, dynamic>? vehicle) {
    if (vehicle == null) return 'Unknown vehicle';
    final name = vehicle['name'] as String?;
    final year = vehicle['year']?.toString();
    final make = vehicle['make'] as String?;
    final model = vehicle['model'] as String?;

    final main = name ?? 'Vehicle';
    final pieces = <String>[];
    if (year != null && year.isNotEmpty) pieces.add(year);
    if (make != null && make.isNotEmpty) pieces.add(make);
    if (model != null && model.isNotEmpty) pieces.add(model);
    final extra = pieces.join(' ');

    if (extra.isEmpty) return main;
    return '$main • $extra';
  }

  Future<void> _markReminderDone(String reminderId) async {
    try {
      await supabase
          .from('reminders')
          .update({'is_active': false}).eq('id', reminderId);
      await _loadData();
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

  Widget _buildStatsRow() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                _buildStatItem(
                  label: 'Vehicles',
                  value: _vehicleCount.toString(),
                ),
                const SizedBox(width: 12),
                _buildStatItem(
                  label: 'Active reminders',
                  value: _activeRemindersCount.toString(),
                ),
                const SizedBox(width: 12),
                _buildStatItem(
                  label: 'Overdue',
                  value: _overdueCount.toString(),
                  color: Colors.red,
                ),
                const SizedBox(width: 12),
                _buildStatItem(
                  label: 'Due soon',
                  value: _dueSoonCount.toString(),
                  color: Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 16),
            Row(
              children: [
                _buildStatItem(
                  label: 'Vehicles with devices',
                  value: _vehiclesWithDevices.toString(),
                  color: Colors.blueGrey,
                ),
                const SizedBox(width: 12),
                _buildStatItem(
                  label: 'Stale devices (24h+)',
                  value: _staleDevices.toString(),
                  color: Colors.redAccent,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    Color? color,
  }) {
    final c = color ?? Colors.black;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: c,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderSection(
    String title,
    List<Map<String, dynamic>> items,
  ) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 4),
        ...items.map(_buildReminderCard),
      ],
    );
  }

  Widget _buildReminderCard(Map<String, dynamic> item) {
    final reminder =
        item['reminder'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final vehicle =
        item['vehicle'] as Map<String, dynamic>?;

    final id = reminder['id'] as String?;
    final type =
        (reminder['reminder_type'] ?? reminder['type']) as String? ??
            'Reminder';
    final nextDateStr =
        _formatDate(reminder['next_due_date'] as String?);
    final nextOdo = reminder['next_due_odometer'] as num?;
    final vehicleTitle = _vehicleTitle(vehicle);
    final status = _statusForReminder(reminder, vehicle);
    final statusColor = _statusColor(status);

    String subtitle = 'Next date: $nextDateStr';
    if (nextOdo != null) {
      subtitle += ' • Next at ${nextOdo.toInt()}';
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: type + status chip
            Row(
              children: [
                Expanded(
                  child: Text(
                    type,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
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
            const SizedBox(height: 4),
            Text(
              vehicleTitle,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (id != null)
                  TextButton.icon(
                    onPressed: () => _markReminderDone(id),
                    icon: const Icon(
                      Icons.check_circle_outline,
                      size: 16,
                    ),
                    label: const Text(
                      'Mark done',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                const SizedBox(width: 8),
                if (vehicle != null)
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              VehicleDetailsPage(vehicle: vehicle),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.directions_car,
                      size: 16,
                    ),
                    label: const Text(
                      'Open vehicle',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                const Spacer(),
                if (vehicle != null)
                  IconButton(
                    tooltip: 'View reminders for this vehicle',
                    iconSize: 18,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RemindersPage(
                            vehicle: vehicle,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.more_horiz),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(8),
                  children: [
                    if (_errorText != null) ...[
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          _errorText!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                    _buildStatsRow(),
                    _buildReminderSection(
                      'Overdue',
                      _overdueReminders,
                    ),
                    _buildReminderSection(
                      'Due soon',
                      _dueSoonReminders,
                    ),
                    _buildReminderSection(
                      'Upcoming',
                      _upcomingReminders,
                    ),
                    if (_overdueReminders.isEmpty &&
                        _dueSoonReminders.isEmpty &&
                        _upcomingReminders.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No active reminders yet. Add reminders from a vehicle to see them here.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
