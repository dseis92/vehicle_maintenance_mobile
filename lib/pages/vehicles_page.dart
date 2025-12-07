import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'vehicle_details_page.dart';
import 'dashboard_page.dart';
import 'shop_mode_page.dart';

final supabase = Supabase.instance.client;

/// Home / garage page – shows all vehicles for the logged-in user.
/// - Inline odometer editing
/// - "Next due" reminder summary on each card
/// - Add vehicle button
/// - AppBar buttons for Shop mode + Dashboard + Reminders
class VehiclesPage extends StatefulWidget {
  const VehiclesPage({super.key});

  @override
  State<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends State<VehiclesPage> {
  bool _loading = true;
  String? _errorText;

  List<Map<String, dynamic>> _vehicles = [];
  // vehicleId -> list of that vehicle's active reminders
  Map<String, List<Map<String, dynamic>>> _remindersByVehicle = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _errorText = 'No user logged in.';
          _vehicles = [];
          _remindersByVehicle = {};
        });
        return;
      }

      // 1) Load vehicles
      final vehiclesResp = await supabase
          .from('vehicles')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: true);

      final vehiclesList =
          (vehiclesResp as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

      // 2) Load all active reminders for this user
      final remindersResp = await supabase
          .from('reminders')
          .select(
            'id, vehicle_id, type, reminder_type, next_due_date, next_due_odometer, interval_days, interval_miles, is_active',
          )
          .eq('user_id', user.id)
          .eq('is_active', true);

      final remindersList =
          (remindersResp as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

      // Group reminders by vehicle
      final Map<String, List<Map<String, dynamic>>> byVehicle = {};
      for (final r in remindersList) {
        final vehicleId = r['vehicle_id'] as String?;
        if (vehicleId == null) continue;
        byVehicle.putIfAbsent(vehicleId, () => []);
        byVehicle[vehicleId]!.add(r);
      }

      setState(() {
        _vehicles = vehiclesList;
        _remindersByVehicle = byVehicle;
      });
    } on PostgrestException catch (e) {
      setState(() {
        _errorText = e.message;
        _vehicles = [];
        _remindersByVehicle = {};
      });
    } catch (e) {
      setState(() {
        _errorText = 'Unexpected error: $e';
        _vehicles = [];
        _remindersByVehicle = {};
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
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

  /// Decide status for reminder for this vehicle (Overdue, Due soon, Upcoming)
  String _statusForReminder(
    Map<String, dynamic> reminder,
    Map<String, dynamic> vehicle,
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
    final vehicleOdo = vehicle['current_odometer'] as num?;

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

  /// Find the "next" reminder for a vehicle (earliest date; fallback to lowest odometer).
  Map<String, dynamic>? _nextReminderForVehicle(
    Map<String, dynamic> vehicle,
  ) {
    final vehicleId = vehicle['id'] as String?;
    if (vehicleId == null) return null;

    final list = _remindersByVehicle[vehicleId];
    if (list == null || list.isEmpty) return null;

    Map<String, dynamic>? best;
    DateTime farFuture = DateTime.now().add(const Duration(days: 36500));
    DateTime bestDate = farFuture;

    // First try earliest date-based
    for (final r in list) {
      final nextDateStr = r['next_due_date'] as String?;
      if (nextDateStr == null) continue;
      try {
        final d = DateTime.parse(nextDateStr);
        if (d.isBefore(bestDate)) {
          bestDate = d;
          best = r;
        }
      } catch (_) {}
    }

    if (best != null) return best;

    // Fallback: lowest next_due_odometer
    num? bestOdo;
    for (final r in list) {
      final nextOdo = r['next_due_odometer'] as num?;
      if (nextOdo == null) continue;
      if (bestOdo == null || nextOdo < bestOdo) {
        bestOdo = nextOdo;
        best = r;
      }
    }

    return best;
  }

  Future<void> _showEditOdometerDialog(Map<String, dynamic> vehicle) async {
    final currentOdo = vehicle['current_odometer'] as num?;
    final unit = vehicle['odometer_unit'] as String? ?? 'mi';

    final controller = TextEditingController(
      text: currentOdo != null ? currentOdo.toInt().toString() : '',
    );

    final result = await showDialog<num?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Update odometer'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Current odometer',
              suffixText: unit,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isEmpty) {
                  Navigator.of(context).pop(null);
                  return;
                }
                final value = num.tryParse(text.replaceAll(',', ''));
                Navigator.of(context).pop(value);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == null) return;

    try {
      await supabase
          .from('vehicles')
          .update({'current_odometer': result}).eq('id', vehicle['id']);
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

  void _showAddVehicleDialog() {
    String name = '';
    String vehicleType = 'car';
    String year = '';
    String make = '';
    String model = '';
    String trim = '';
    String odo = '';
    String unit = 'mi';
    String notes = '';

    showDialog(
      context: context,
      builder: (context) {
        final nameController = TextEditingController(text: name);
        final yearController = TextEditingController(text: year);
        final makeController = TextEditingController(text: make);
        final modelController = TextEditingController(text: model);
        final trimController = TextEditingController(text: trim);
        final odoController = TextEditingController(text: odo);
        final notesController = TextEditingController(text: notes);

        bool saving = false;

        return StatefulBuilder(
          builder: (context, setLocalState) {
            Future<void> save() async {
              if (saving) return;

              final vName = nameController.text.trim();
              if (vName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vehicle name is required.'),
                  ),
                );
                return;
              }

              final user = supabase.auth.currentUser;
              if (user == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No user logged in.'),
                  ),
                );
                return;
              }

              int? yearInt;
              if (yearController.text.trim().isNotEmpty) {
                yearInt = int.tryParse(yearController.text.trim());
              }
              num? odoNum;
              if (odoController.text.trim().isNotEmpty) {
                odoNum = num.tryParse(
                  odoController.text.trim().replaceAll(',', ''),
                );
              }

              setLocalState(() => saving = true);

              try {
                await supabase.from('vehicles').insert({
                  'user_id': user.id,
                  'name': vName,
                  'vehicle_type': vehicleType,
                  'year': yearInt,
                  'make': makeController.text.trim().isNotEmpty
                      ? makeController.text.trim()
                      : null,
                  'model': modelController.text.trim().isNotEmpty
                      ? modelController.text.trim()
                      : null,
                  'trim': trimController.text.trim().isNotEmpty
                      ? trimController.text.trim()
                      : null,
                  'current_odometer': odoNum,
                  'odometer_unit': unit,
                  'notes': notesController.text.trim().isNotEmpty
                      ? notesController.text.trim()
                      : null,
                });

                if (context.mounted) {
                  Navigator.of(context).pop();
                }
                await _loadData();
              } on PostgrestException catch (e) {
                setLocalState(() => saving = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.message)),
                );
              } catch (e) {
                setLocalState(() => saving = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            }

            return AlertDialog(
              title: const Text('Add vehicle'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Vehicle name',
                        hintText: 'e.g. Dually, Shop Truck',
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: vehicleType,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'car',
                          child: Text('Car'),
                        ),
                        DropdownMenuItem(
                          value: 'truck',
                          child: Text('Truck'),
                        ),
                        DropdownMenuItem(
                          value: 'van',
                          child: Text('Van'),
                        ),
                        DropdownMenuItem(
                          value: 'motorcycle',
                          child: Text('Motorcycle'),
                        ),
                        DropdownMenuItem(
                          value: 'golf_cart',
                          child: Text('Golf Cart'),
                        ),
                        DropdownMenuItem(
                          value: 'equipment',
                          child: Text('Equipment'),
                        ),
                        DropdownMenuItem(
                          value: 'other',
                          child: Text('Other'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setLocalState(() => vehicleType = v);
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: yearController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Year',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: makeController,
                            decoration: const InputDecoration(
                              labelText: 'Make',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: modelController,
                            decoration: const InputDecoration(
                              labelText: 'Model',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: trimController,
                      decoration: const InputDecoration(
                        labelText: 'Trim (optional)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: odoController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Current odometer',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: unit,
                          items: const [
                            DropdownMenuItem(
                              value: 'mi',
                              child: Text('mi'),
                            ),
                            DropdownMenuItem(
                              value: 'km',
                              child: Text('km'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setLocalState(() => unit = v);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesController,
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
                  onPressed:
                      saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: saving ? null : save,
                  child: saving
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

  String _vehicleTypeLabel(String? type) {
    switch (type) {
      case 'car':
        return 'Car';
      case 'truck':
        return 'Truck';
      case 'van':
        return 'Van';
      case 'motorcycle':
        return 'Motorcycle';
      case 'golf_cart':
        return 'Golf Cart';
      case 'equipment':
        return 'Equipment';
      case 'other':
        return 'Other';
      default:
        return '';
    }
  }

  Widget _buildVehicleCard(Map<String, dynamic> v) {
    final name = v['name'] as String? ?? 'Vehicle';
    final typeLabel = _vehicleTypeLabel(v['vehicle_type'] as String?);
    final year = v['year']?.toString();
    final make = v['make'] as String?;
    final model = v['model'] as String?;
    final trim = v['trim'] as String?;
    final currentOdo = v['current_odometer'] as num?;
    final unit = v['odometer_unit'] as String? ?? 'mi';

    final subtitleParts = <String>[];
    if (year != null && year.isNotEmpty) subtitleParts.add(year);
    if (make != null && make.isNotEmpty) subtitleParts.add(make);
    if (model != null && model.isNotEmpty) subtitleParts.add(model);
    if (trim != null && trim.isNotEmpty) subtitleParts.add(trim);
    final subtitle = subtitleParts.join(' ');

    String odoText =
        currentOdo != null ? '${currentOdo.toInt()} $unit' : 'Not set';

    final nextReminder = _nextReminderForVehicle(v);
    String nextLine = 'No reminders set';
    String status = '';
    Color statusColor = Colors.grey;

    if (nextReminder != null) {
      final type =
          (nextReminder['reminder_type'] ?? nextReminder['type'])
                  as String? ??
              'Reminder';
      final dateStr =
          _formatDate(nextReminder['next_due_date'] as String?);
      final nextOdo = nextReminder['next_due_odometer'] as num?;

      final s = _statusForReminder(nextReminder, v);
      status = s;
      statusColor = _statusColor(s);

      if (nextOdo != null) {
        nextLine =
            '$type – $dateStr • next at ${nextOdo.toInt()} $unit';
      } else {
        nextLine = '$type – $dateStr';
      }
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VehicleDetailsPage(vehicle: v),
          ),
        );
      },
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor:
                    Theme.of(context).colorScheme.primary.withOpacity(0.1),
                child: Icon(
                  Icons.directions_car,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (status.isNotEmpty)
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
                    if (typeLabel.isNotEmpty)
                      Text(
                        typeLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          'Odometer: $odoText',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Edit odometer',
                          iconSize: 18,
                          padding: EdgeInsets.zero,
                          onPressed: () => _showEditOdometerDialog(v),
                          icon: const Icon(Icons.edit),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      nextLine,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your vehicles'),
        actions: [
          IconButton(
            tooltip: 'Shop mode',
            icon: const Icon(Icons.home_repair_service_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ShopModePage(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Dashboard',
            icon: const Icon(Icons.dashboard_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DashboardPage(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Reminders',
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DashboardPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _vehicles.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(16),
                      children: const [
                        Text(
                          'No vehicles yet. Tap the + button to add your first vehicle.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    )
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
                        ..._vehicles.map(_buildVehicleCard),
                      ],
                    ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddVehicleDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add vehicle'),
      ),
    );
  }
}
