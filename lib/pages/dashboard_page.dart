import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_constants.dart';
import '../services/auth_service.dart';
import '../services/vehicle_service.dart';
import '../services/reminder_service.dart';
import '../services/device_service.dart';
import '../utils/date_helpers.dart';
import '../utils/reminder_helpers.dart';
import 'vehicle_details_page.dart';
import 'reminders_page.dart';

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
      final user = AuthService().currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _errorText = 'No user logged in.';
          });
        }
        return;
      }

      // ---- Load vehicles ----
      final vehiclesList = await VehicleService().getVehicles();
      _vehicleCount = vehiclesList.length;

      final Map<String, Map<String, dynamic>> vehiclesById = {};
      for (final v in vehiclesList) {
        final id = v['id'] as String?;
        if (id != null) {
          vehiclesById[id] = v;
        }
      }

      // ---- Load active reminders ----
      final remindersList = await ReminderService().getReminders();
      _activeRemindersCount = remindersList.length;

      // ---- Classify reminders: Overdue / Due soon / Upcoming ----
      _overdueReminders = [];
      _dueSoonReminders = [];
      _upcomingReminders = [];

      for (final r in remindersList) {
        final vehicleId = r['vehicle_id'] as String?;
        final vehicle = vehicleId != null ? vehiclesById[vehicleId] : null;

        final status = ReminderHelpers.calculateStatus(r, vehicle);
        final item = {
          'reminder': r,
          'vehicle': vehicle,
        };

        if (status == ReminderStatus.overdue) {
          _overdueReminders.add(item);
        } else if (status == ReminderStatus.dueSoon) {
          _dueSoonReminders.add(item);
        } else if (status == ReminderStatus.upcoming) {
          _upcomingReminders.add(item);
        }
      }

      _overdueCount = _overdueReminders.length;
      _dueSoonCount = _dueSoonReminders.length;

      // ---- IoT summary: vehicles with devices & stale devices ----
      await _loadIoTSummary(user.id);
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() {
          _errorText = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = 'Unexpected error: $e';
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

  Future<void> _loadIoTSummary(String userId) async {
    // Get all device links for this user
    final linksList = await DeviceService().getDeviceLinks();

    if (linksList.isEmpty) {
      if (mounted) {
        setState(() {
          _vehiclesWithDevices = 0;
          _staleDevices = 0;
        });
      }
      return;
    }

    // Count distinct vehicles with at least one device
    final vehicleIds = <String>{};
    for (final l in linksList) {
      final vId = l['vehicle_id'] as String?;
      if (vId != null) vehicleIds.add(vId);
    }

    // Get stale device count
    final staleCount = await DeviceService().getStaleDeviceCount();

    if (mounted) {
      setState(() {
        _vehiclesWithDevices = vehicleIds.length;
        _staleDevices = staleCount;
      });
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
      await ReminderService().updateReminder(
        reminderId,
        {'is_active': false},
      );
      await _loadData();
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() {
          _errorText = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = 'Unexpected error: $e';
        });
      }
    }
  }

  Widget _buildStatsRow() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UiConstants.borderRadiusMedium),
      ),
      margin: EdgeInsets.symmetric(
        vertical: UiConstants.spacingSmall,
        horizontal: 4,
      ),
      child: Padding(
        padding: EdgeInsets.all(UiConstants.spacingMedium),
        child: Column(
          children: [
            Row(
              children: [
                _buildStatItem(
                  label: 'Vehicles',
                  value: _vehicleCount.toString(),
                ),
                SizedBox(width: UiConstants.spacingMedium),
                _buildStatItem(
                  label: 'Active reminders',
                  value: _activeRemindersCount.toString(),
                ),
                SizedBox(width: UiConstants.spacingMedium),
                _buildStatItem(
                  label: 'Overdue',
                  value: _overdueCount.toString(),
                  color: Colors.red,
                ),
                SizedBox(width: UiConstants.spacingMedium),
                _buildStatItem(
                  label: 'Due soon',
                  value: _dueSoonCount.toString(),
                  color: Colors.orange,
                ),
              ],
            ),
            SizedBox(height: UiConstants.spacingSmall),
            const Divider(height: 16),
            Row(
              children: [
                _buildStatItem(
                  label: 'Vehicles with devices',
                  value: _vehiclesWithDevices.toString(),
                  color: Colors.blueGrey,
                ),
                SizedBox(width: UiConstants.spacingMedium),
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
        SizedBox(height: UiConstants.spacingMedium),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: UiConstants.spacingSmall),
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
        DateHelpers.formatDate(reminder['next_due_date'] as String?);
    final nextOdo = reminder['next_due_odometer'] as num?;
    final vehicleTitle = _vehicleTitle(vehicle);
    final status = ReminderHelpers.calculateStatus(reminder, vehicle);
    final statusColor = ReminderHelpers.getStatusColor(status);

    String subtitle = 'Next date: $nextDateStr';
    if (nextOdo != null) {
      subtitle += ' • Next at ${nextOdo.toInt()}';
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UiConstants.borderRadiusMedium),
      ),
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Padding(
        padding: EdgeInsets.all(UiConstants.spacingMedium),
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
                  padding: EdgeInsets.symmetric(
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
            SizedBox(height: UiConstants.spacingSmall),
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
                SizedBox(width: UiConstants.spacingSmall),
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
                  padding: EdgeInsets.all(UiConstants.spacingSmall),
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
                      Padding(
                        padding: EdgeInsets.all(UiConstants.spacingMedium),
                        child: const Text(
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
