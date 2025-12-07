import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'vehicle_details_page.dart';

final supabase = Supabase.instance.client;

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
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _errorText = 'No user logged in.';
          _vehicles = [];
          _lastChargeByVehicleId = {};
        });
        return;
      }

      // Load all vehicles for this user
      final vehiclesResp = await supabase
          .from('vehicles')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: true);

      final vehiclesList =
          (vehiclesResp as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

      // Collect golf cart IDs for charge-rotation lookup
      final golfCartIds = <String>{};
      for (final v in vehiclesList) {
        final type = v['vehicle_type'] as String?;
        final id = v['id'] as String?;
        if (type == 'golf_cart' && id != null) {
          golfCartIds.add(id);
        }
      }

      Map<String, DateTime?> lastCharge = {};

      if (golfCartIds.isNotEmpty) {
        // Load all Charge rotation events for this user, newest first
        final eventsResp = await supabase
            .from('service_events')
            .select('vehicle_id, service_date, category')
            .eq('user_id', user.id)
            .eq('category', 'Charge rotation')
            .order('service_date', ascending: false);

        final eventsList =
            (eventsResp as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

        // First occurrence per vehicle (since sorted desc = newest),
        // but only for golf cart IDs we care about.
        for (final e in eventsList) {
          final vehicleId = e['vehicle_id'] as String?;
          final dateStr = e['service_date'] as String?;
          if (vehicleId == null || dateStr == null) continue;
          if (!golfCartIds.contains(vehicleId)) continue;
          if (lastCharge.containsKey(vehicleId)) continue;
          try {
            lastCharge[vehicleId] = DateTime.parse(dateStr);
          } catch (_) {
            // skip invalid dates
          }
        }
      }

      setState(() {
        _vehicles = vehiclesList;
        _lastChargeByVehicleId = lastCharge;
      });
    } on PostgrestException catch (e) {
      setState(() {
        _errorText = e.message;
        _vehicles = [];
        _lastChargeByVehicleId = {};
      });
    } catch (e) {
      setState(() {
        _errorText = 'Unexpected error: $e';
        _vehicles = [];
        _lastChargeByVehicleId = {};
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  String _formatDate(DateTime? d) {
    if (d == null) return 'Not set';
    return '${d.month}/${d.day}/${d.year}';
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

  Future<void> _showQuickOdometerDialog(Map<String, dynamic> vehicle) async {
    final currentOdo = vehicle['current_odometer'] as num?;
    final unit = vehicle['odometer_unit'] as String? ?? 'mi';

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
                final parsed =
                    num.tryParse(text.replaceAll(',', ''));
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
      await supabase
          .from('vehicles')
          .update({'current_odometer': value}).eq('id', vehicle['id']);

      // refresh list
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

  Future<void> _quickCharge(Map<String, dynamic> vehicle,
      {DateTime? date}) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        _errorText = 'No user logged in.';
      });
      return;
    }

    final vehicleId = vehicle['id'] as String?;
    if (vehicleId == null) {
      setState(() {
        _errorText = 'Vehicle ID missing.';
      });
      return;
    }

    final DateTime serviceDate = date ?? DateTime.now();

    try {
      await supabase.from('service_events').insert({
        'user_id': user.id,
        'vehicle_id': vehicleId,
        'service_date': serviceDate.toIso8601String(),
        'category': 'Charge rotation',
        'odometer': null,
        'cost': null,
        'performed_by': 'Shop',
        'notes': null,
      });

      setState(() {
        _lastChargeByVehicleId[vehicleId] = serviceDate;
      });
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

  Future<void> _pickChargeDate(Map<String, dynamic> vehicle) async {
    final initial = _lastChargeByVehicleId[vehicle['id']] ??
        DateTime.now();

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
    final typeLabel = _vehicleTypeLabel(type);
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

    final isGolfCart = type == 'golf_cart';
    final vehicleId = v['id'] as String?;
    final lastCharge =
        vehicleId != null ? _lastChargeByVehicleId[vehicleId] : null;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        // Still allow full details when tapped
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
                radius: 22,
                backgroundColor:
                    Theme.of(context).colorScheme.primary.withOpacity(0.1),
                child: Icon(
                  isGolfCart
                      ? Icons.electric_scooter
                      : Icons.directions_car,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
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
                          onPressed: () =>
                              _showQuickOdometerDialog(v),
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
                        'Last charge: ${_formatDate(lastCharge)}',
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
                      padding: const EdgeInsets.all(16),
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
    );
  }
}
