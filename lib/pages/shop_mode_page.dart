import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_constants.dart';
import '../services/service_event_service.dart';
import '../services/vehicle_service.dart';
import '../utils/date_helpers.dart';
import '../utils/number_helpers.dart';
import 'vehicle_details_page.dart';

/// Shop Mode:
/// - Tech-friendly list of vehicles
/// - Non–golf carts: quick odometer update
/// - Golf carts: quick "charge date" (creates a Charge rotation service event)
class ShopModePage extends StatefulWidget {
  const ShopModePage({super.key});

  @override
  State<ShopModePage> createState() => _ShopModePageState();
}

class _ShopModePageState extends State<ShopModePage> {
  final _vehicleService = VehicleService();
  final _serviceEventService = ServiceEventService();

  bool _loading = true;
  String? _errorText;

  List<Map<String, dynamic>> _vehicles = [];

  /// vehicle_id -> last charge service_date (for Charge rotation)
  Map<String, DateTime?> _lastChargeByVehicleId = {};

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
      // Load all vehicles for this user
      final vehiclesList = await _vehicleService.getVehicles();

      // Collect golf cart IDs for charge-rotation lookup
      final golfCartIds = <String>{};
      for (final v in vehiclesList) {
        final type = v['vehicle_type'] as String?;
        final id = v['id'] as String?;
        if (type == VehicleTypes.golfCart && id != null) {
          golfCartIds.add(id);
        }
      }

      final lastCharge = <String, DateTime?>{};

      if (golfCartIds.isNotEmpty) {
        // Load charge rotation events for golf carts
        for (final cartId in golfCartIds) {
          final events = await _serviceEventService.getServiceEventsByCategory(
            cartId,
            MaintenanceCategories.chargeRotation,
          );

          if (events.isNotEmpty) {
            final dateStr = events.first['service_date'] as String?;
            if (dateStr != null) {
              try {
                lastCharge[cartId] = DateTime.parse(dateStr);
              } catch (_) {
                // skip invalid dates
              }
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _vehicles = vehiclesList;
          _lastChargeByVehicleId = lastCharge;
        });
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() {
          _errorText = e.message;
          _vehicles = [];
          _lastChargeByVehicleId = {};
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = 'Unexpected error: $e';
          _vehicles = [];
          _lastChargeByVehicleId = {};
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

  Future<void> _showQuickOdometerDialog(Map<String, dynamic> vehicle) async {
    final currentOdo = vehicle['current_odometer'] as num?;
    final unit = vehicle['odometer_unit'] as String? ?? OdometerUnits.miles;

    final controller = TextEditingController(
      text: currentOdo != null ? currentOdo.toInt().toString() : '',
    );

    final value = await showDialog<num?>(
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
                final parsed = NumberHelpers.parseNumber(text);
                Navigator.of(context).pop(parsed);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (value == null) return;

    try {
      await _vehicleService.updateOdometer(vehicle['id'], value);

      // refresh list
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

  Future<void> _quickCharge(Map<String, dynamic> vehicle,
      {DateTime? date}) async {
    final vehicleId = vehicle['id'] as String?;
    if (vehicleId == null) {
      setState(() {
        _errorText = 'Vehicle ID missing.';
      });
      return;
    }

    final DateTime serviceDate = date ?? DateTime.now();

    try {
      await _serviceEventService.createServiceEvent(
        vehicleId: vehicleId,
        serviceDate: serviceDate.toIso8601String(),
        category: MaintenanceCategories.chargeRotation,
        performedBy: 'Shop',
      );

      if (mounted) {
        setState(() {
          _lastChargeByVehicleId[vehicleId] = serviceDate;
        });
      }
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

  Future<void> _pickChargeDate(Map<String, dynamic> vehicle) async {
    final initial = _lastChargeByVehicleId[vehicle['id']] ?? DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    await _quickCharge(vehicle, date: picked);
  }

  Widget _buildVehicleCard(Map<String, dynamic> v) {
    final name = v['name'] as String? ?? 'Vehicle';
    final type = v['vehicle_type'] as String? ?? '';
    final typeLabel = VehicleTypes.getLabel(type);
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

    final isGolfCart = type == VehicleTypes.golfCart;
    final vehicleId = v['id'] as String?;
    final lastCharge =
        vehicleId != null ? _lastChargeByVehicleId[vehicleId] : null;

    return InkWell(
      borderRadius: BorderRadius.circular(UiConstants.borderRadiusMedium),
      onTap: () {
        // Still allow full details when tapped
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VehicleDetailsPage(vehicle: v),
          ),
        );
      },
      child: Card(
        elevation: UiConstants.cardElevation - 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UiConstants.borderRadiusMedium),
        ),
        margin: const EdgeInsets.symmetric(
          vertical: 6,
          horizontal: 4,
        ),
        child: Padding(
          padding: const EdgeInsets.all(UiConstants.spacingSmall + 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor:
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                child: Icon(
                  VehicleTypes.getIcon(type),
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: UiConstants.spacingSmall + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
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
                    if (!isGolfCart) ...[
                      // Non-golf carts: quick odometer
                      Text(
                        'Odometer: $odoText',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: () => _showQuickOdometerDialog(v),
                          icon: const Icon(
                            Icons.speed,
                            size: 16,
                          ),
                          label: const Text(
                            'Quick odometer',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ] else ...[
                      // Golf carts: quick charge date
                      Text(
                        'Last charge: ${DateHelpers.formatDateTime(lastCharge)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _quickCharge(v),
                            icon: const Icon(
                              Icons.bolt,
                              size: 16,
                            ),
                            label: const Text(
                              'Charge today',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _pickChargeDate(v),
                            icon: const Icon(
                              Icons.calendar_today,
                              size: 16,
                            ),
                            label: const Text(
                              'Pick date',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
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
        title: const Text('Shop mode'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _vehicles.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(UiConstants.spacingMedium),
                      children: const [
                        Text(
                          'No vehicles yet. Add vehicles from the main garage first.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(UiConstants.spacingSmall),
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
    );
  }
}
