import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../services/auth_service.dart';
import '../services/vehicle_service.dart';
import '../services/reminder_service.dart';
import '../utils/date_helpers.dart';
import '../utils/reminder_helpers.dart';
import '../utils/number_helpers.dart';
import '../utils/validation_helpers.dart';
import 'vehicle_details_page.dart';
import 'dashboard_page.dart';
import 'shop_mode_page.dart';

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

  final _vehicleService = VehicleService();
  final _reminderService = ReminderService();
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final user = _authService.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _errorText = 'No user logged in.';
          _vehicles = [];
          _remindersByVehicle = {};
        });
        return;
      }

      // 1) Load vehicles
      final vehiclesList = await _vehicleService.getVehicles();

      // 2) Load all active reminders for this user
      final remindersList = await _reminderService.getReminders();

      // Group reminders by vehicle
      final Map<String, List<Map<String, dynamic>>> byVehicle = {};
      for (final r in remindersList) {
        final vehicleId = r['vehicle_id'] as String?;
        if (vehicleId == null) continue;
        byVehicle.putIfAbsent(vehicleId, () => []);
        byVehicle[vehicleId]!.add(r);
      }

      if (!mounted) return;
      setState(() {
        _vehicles = vehiclesList;
        _remindersByVehicle = byVehicle;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = 'Error loading data: $e';
          _vehicles = [];
          _remindersByVehicle = {};
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
    final unit = vehicle['odometer_unit'] as String? ?? OdometerUnits.miles;

    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController(
      text: currentOdo != null ? currentOdo.toInt().toString() : '',
    );

    final result = await showDialog<num?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Update odometer'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Current odometer',
                suffixText: unit,
              ),
              validator: ValidationHelpers.validateOdometer,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final text = controller.text.trim();
                if (text.isEmpty) {
                  Navigator.of(context).pop(null);
                  return;
                }
                final value = NumberHelpers.parseNumber(text);
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
      await _vehicleService.updateOdometer(vehicle['id'] as String, result);
      if (!mounted) return;
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Error updating odometer: $e';
      });
    }
  }

  void _showAddVehicleDialog() {
    final formKey = GlobalKey<FormState>();

    final nameController = TextEditingController();
    final yearController = TextEditingController();
    final makeController = TextEditingController();
    final modelController = TextEditingController();
    final trimController = TextEditingController();
    final odoController = TextEditingController();
    final notesController = TextEditingController();

    String vehicleType = VehicleTypes.car;
    String unit = OdometerUnits.miles;

    showDialog(
      context: context,
      builder: (context) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setLocalState) {
            Future<void> save() async {
              if (saving) return;
              if (!formKey.currentState!.validate()) return;

              final user = _authService.currentUser;
              if (user == null) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No user logged in.'),
                  ),
                );
                return;
              }

              final yearText = yearController.text.trim().isNotEmpty
                  ? yearController.text.trim()
                  : null;

              num? odoNum;
              if (odoController.text.trim().isNotEmpty) {
                odoNum = NumberHelpers.parseNumber(odoController.text.trim());
              }

              setLocalState(() => saving = true);

              try {
                await _vehicleService.createVehicle(
                  name: nameController.text.trim(),
                  vehicleType: vehicleType,
                  year: yearText,
                  make: makeController.text.trim().isNotEmpty
                      ? makeController.text.trim()
                      : null,
                  model: modelController.text.trim().isNotEmpty
                      ? modelController.text.trim()
                      : null,
                  trim: trimController.text.trim().isNotEmpty
                      ? trimController.text.trim()
                      : null,
                  currentOdometer: odoNum,
                  odometerUnit: unit,
                  notes: notesController.text.trim().isNotEmpty
                      ? notesController.text.trim()
                      : null,
                );

                if (context.mounted) {
                  Navigator.of(context).pop();
                }
                await _loadData();
              } catch (e) {
                setLocalState(() => saving = false);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            }

            return AlertDialog(
              title: const Text('Add vehicle'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Vehicle name',
                          hintText: 'e.g. Dually, Shop Truck',
                        ),
                        validator: (value) =>
                            ValidationHelpers.validateRequired(value, 'Vehicle name'),
                      ),
                      SizedBox(height: UiConstants.spacingMedium),
                      DropdownButtonFormField<String>(
                        initialValue: vehicleType,
                        decoration: const InputDecoration(
                          labelText: 'Type',
                        ),
                        items: VehicleTypes.getDropdownItems(),
                        onChanged: (v) {
                          if (v == null) return;
                          setLocalState(() => vehicleType = v);
                        },
                      ),
                      SizedBox(height: UiConstants.spacingMedium),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: yearController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Year',
                              ),
                              validator: ValidationHelpers.validateVehicleYear,
                            ),
                          ),
                          SizedBox(width: UiConstants.spacingMedium),
                          Expanded(
                            child: TextFormField(
                              controller: makeController,
                              decoration: const InputDecoration(
                                labelText: 'Make',
                              ),
                            ),
                          ),
                          SizedBox(width: UiConstants.spacingMedium),
                          Expanded(
                            child: TextFormField(
                              controller: modelController,
                              decoration: const InputDecoration(
                                labelText: 'Model',
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: UiConstants.spacingMedium),
                      TextFormField(
                        controller: trimController,
                        decoration: const InputDecoration(
                          labelText: 'Trim (optional)',
                        ),
                      ),
                      SizedBox(height: UiConstants.spacingMedium),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: odoController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Current odometer',
                              ),
                              validator: ValidationHelpers.validateOdometer,
                            ),
                          ),
                          SizedBox(width: UiConstants.spacingMedium),
                          DropdownButton<String>(
                            value: unit,
                            items: OdometerUnits.getDropdownItems(),
                            onChanged: (v) {
                              if (v == null) return;
                              setLocalState(() => unit = v);
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: UiConstants.spacingMedium),
                      TextFormField(
                        controller: notesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                        ),
                      ),
                    ],
                  ),
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

  Widget _buildVehicleCard(Map<String, dynamic> v) {
    final name = v['name'] as String? ?? 'Vehicle';
    final vehicleType = v['vehicle_type'] as String? ?? '';
    final typeLabel = VehicleTypes.getLabel(vehicleType);
    final typeIcon = VehicleTypes.getIcon(vehicleType);
    final year = v['year']?.toString();
    final make = v['make'] as String?;
    final model = v['model'] as String?;
    final trim = v['trim'] as String?;
    final currentOdo = v['current_odometer'] as num?;
    final unit = v['odometer_unit'] as String? ?? OdometerUnits.miles;

    final subtitleParts = <String>[];
    if (year != null && year.isNotEmpty) subtitleParts.add(year);
    if (make != null && make.isNotEmpty) subtitleParts.add(make);
    if (model != null && model.isNotEmpty) subtitleParts.add(model);
    if (trim != null && trim.isNotEmpty) subtitleParts.add(trim);
    final subtitle = subtitleParts.join(' ');

    final odoText = NumberHelpers.formatOdometer(currentOdo, unit);

    final nextReminder = _nextReminderForVehicle(v);
    String nextLine = 'No reminders set';
    String status = '';
    Color statusColor = Colors.grey;

    if (nextReminder != null) {
      final type =
          (nextReminder['reminder_type'] ?? nextReminder['type'])
                  as String? ??
              'Reminder';
      final dateStr = DateHelpers.formatDate(
        nextReminder['next_due_date'] as String?,
      );
      final nextOdo = nextReminder['next_due_odometer'] as num?;

      final s = ReminderHelpers.calculateStatus(nextReminder, v);
      status = s;
      statusColor = _statusColor(s);

      if (nextOdo != null) {
        nextLine =
            '$type – $dateStr • next at ${NumberHelpers.formatOdometer(nextOdo, unit)}';
      } else {
        nextLine = '$type – $dateStr';
      }
    }

    return InkWell(
      borderRadius: BorderRadius.circular(UiConstants.borderRadiusMedium),
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
          borderRadius: BorderRadius.circular(UiConstants.borderRadiusMedium),
        ),
        margin: EdgeInsets.symmetric(
          vertical: UiConstants.spacingSmall,
          horizontal: 4.0,
        ),
        child: Padding(
          padding: EdgeInsets.all(UiConstants.spacingMedium),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor:
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                child: Icon(
                  typeIcon,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              SizedBox(width: UiConstants.spacingMedium),
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
                            padding: EdgeInsets.symmetric(
                              horizontal: UiConstants.spacingMedium,
                              vertical: 4.0,
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
                    SizedBox(height: UiConstants.spacingSmall),
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
                      padding: EdgeInsets.all(UiConstants.spacingLarge),
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
                      padding: EdgeInsets.all(UiConstants.spacingMedium),
                      children: [
                        if (_errorText != null) ...[
                          Padding(
                            padding: EdgeInsets.all(4.0),
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
