import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'reminders_page.dart';
import 'dashboard_page.dart';

final supabase = Supabase.instance.client;

class VehicleDetailsPage extends StatefulWidget {
  final Map<String, dynamic> vehicle;

  const VehicleDetailsPage({super.key, required this.vehicle});

  @override
  State<VehicleDetailsPage> createState() => _VehicleDetailsPageState();
}

class _VehicleDetailsPageState extends State<VehicleDetailsPage> {
  bool _loading = true;
  String? _errorText;
  List<Map<String, dynamic>> _serviceEvents = [];

  // Fresh vehicle row from DB (so edits show up)
  Map<String, dynamic>? _vehicleRow;

  // IoT: device links + latest telemetry
  bool _iotLoading = false;
  List<Map<String, dynamic>> _deviceLinks = [];
  Map<String, dynamic>? _latestTelemetry;

  // Add service event form state
  DateTime _serviceDate = DateTime.now();
  String _serviceCategory = 'Oil change';
  final TextEditingController _odometerController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _performedByController =
      TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _savingEvent = false;

  @override
  void initState() {
    super.initState();
    _loadVehicleRow();
    _loadServiceEvents();
    _loadIoTData();
  }

  @override
  void dispose() {
    _odometerController.dispose();
    _costController.dispose();
    _performedByController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _vehicleData =>
      _vehicleRow ?? widget.vehicle;

  Future<void> _loadVehicleRow() async {
    final vehicleId = widget.vehicle['id'] as String?;
    if (vehicleId == null) return;

    try {
      final resp = await supabase
          .from('vehicles')
          .select()
          .eq('id', vehicleId)
          .maybeSingle();

      if (resp != null) {
        setState(() {
          _vehicleRow =
              Map<String, dynamic>.from(resp as Map<dynamic, dynamic>);
        });
      }
    } on PostgrestException catch (e) {
      setState(() {
        _errorText ??= e.message;
      });
    } catch (e) {
      setState(() {
        _errorText ??= 'Unexpected error loading vehicle: $e';
      });
    }
  }

  Future<void> _loadServiceEvents() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final vehicleId = widget.vehicle['id'] as String?;
      if (vehicleId == null) {
        setState(() {
          _errorText = 'Vehicle ID missing.';
          _serviceEvents = [];
        });
        return;
      }

      final resp = await supabase
          .from('service_events')
          .select()
          .eq('vehicle_id', vehicleId)
          .order('service_date', ascending: false)
          .order('created_at', ascending: false);

      final list =
          (resp as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

      setState(() {
        _serviceEvents = list;
      });
    } on PostgrestException catch (e) {
      setState(() {
        _errorText = e.message;
        _serviceEvents = [];
      });
    } catch (e) {
      setState(() {
        _errorText = 'Unexpected error: $e';
        _serviceEvents = [];
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loadIoTData() async {
    final vehicleId = widget.vehicle['id'] as String?;
    if (vehicleId == null) {
      setState(() {
        _deviceLinks = [];
        _latestTelemetry = null;
      });
      return;
    }

    setState(() {
      _iotLoading = true;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _deviceLinks = [];
          _latestTelemetry = null;
        });
        return;
      }

      // Device links for this vehicle
      final linksResp = await supabase
          .from('device_links')
          .select()
          .eq('user_id', user.id)
          .eq('vehicle_id', vehicleId)
          .order('created_at', ascending: true);

      final linksList =
          (linksResp as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

      // Latest telemetry event for this vehicle
      final telemetryResp = await supabase
          .from('telemetry_events')
          .select()
          .eq('user_id', user.id)
          .eq('vehicle_id', vehicleId)
          .order('recorded_at', ascending: false)
          .limit(1)
          .maybeSingle();

      Map<String, dynamic>? latest;
      if (telemetryResp != null) {
        latest =
            Map<String, dynamic>.from(telemetryResp as Map<dynamic, dynamic>);
      }

      setState(() {
        _deviceLinks = linksList;
        _latestTelemetry = latest;
      });
    } on PostgrestException catch (e) {
      setState(() {
        _errorText ??= e.message;
      });
    } catch (e) {
      setState(() {
        _errorText ??= 'Unexpected IoT error: $e';
      });
    } finally {
      setState(() {
        _iotLoading = false;
      });
    }
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return 'Unknown date';
    try {
      final d = DateTime.parse(isoString);
      return '${d.month}/${d.day}/${d.year}';
    } catch (_) {
      return isoString;
    }
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null) return 'Unknown';
    try {
      final d = DateTime.parse(isoString).toLocal();
      final date = '${d.month}/${d.day}/${d.year}';
      final time =
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
      return '$date • $time';
    } catch (_) {
      return isoString;
    }
  }

  String _formatCurrency(num? value) {
    if (value == null) return '-';
    return '\$${value.toStringAsFixed(2)}';
  }

  // ====== ADD SERVICE EVENT ======

  void _showAddServiceEventDialog() {
    _serviceDate = DateTime.now();
    _serviceCategory = 'Oil change';
    _odometerController.text = '';
    _costController.text = '';
    _performedByController.text = '';
    _notesController.text = '';
    _savingEvent = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            final latest = _latestTelemetry;

            Future<void> pickServiceDate() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _serviceDate,
                firstDate: DateTime(1990),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                setLocalState(() {
                  _serviceDate = picked;
                });
              }
            }

            final dateLabel =
                '${_serviceDate.month}/${_serviceDate.day}/${_serviceDate.year}';

            return AlertDialog(
              title: const Text('Add service event'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Service date',
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
                        onPressed: pickServiceDate,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _serviceCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
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
                      onChanged: (value) {
                        if (value == null) return;
                        setLocalState(() {
                          _serviceCategory = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _odometerController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Odometer',
                        hintText: 'e.g. 125000',
                      ),
                    ),
                    if (latest != null && latest['odometer'] != null) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () {
                            final odoVal = latest['odometer'] as num;
                            setLocalState(() {
                              _odometerController.text =
                                  odoVal.toInt().toString();
                            });
                          },
                          icon: const Icon(Icons.speed, size: 16),
                          label: Text(
                            'Use latest from device (${(latest['odometer'] as num).toInt()})',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Last reading: ${_formatDateTime(latest['recorded_at'] as String?)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextField(
                      controller: _costController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Cost (optional)',
                        prefixText: '\$',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _performedByController,
                      decoration: const InputDecoration(
                        labelText: 'Performed by (optional)',
                        hintText: 'Self or shop name',
                      ),
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
                  onPressed: _savingEvent
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: _savingEvent ? null : _saveServiceEvent,
                  child: _savingEvent
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

  Future<void> _saveServiceEvent() async {
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

    final odoText = _odometerController.text.trim();
    final costText = _costController.text.trim();
    final performedBy = _performedByController.text.trim();
    final notes = _notesController.text.trim();

    int? odometerValue;
    if (odoText.isNotEmpty) {
      odometerValue = int.tryParse(odoText.replaceAll(',', ''));
      if (odometerValue == null) {
        setState(() {
          _errorText = 'Odometer must be a number.';
        });
        return;
      }
    }

    num? costValue;
    if (costText.isNotEmpty) {
      costValue = num.tryParse(costText.replaceAll(',', ''));
      if (costValue == null) {
        setState(() {
          _errorText = 'Cost must be a number.';
        });
        return;
      }
    }

    setState(() {
      _savingEvent = true;
      _errorText = null;
    });

    try {
      await supabase.from('service_events').insert({
        'user_id': user.id,
        'vehicle_id': vehicleId,
        'service_date': _serviceDate.toIso8601String(),
        'category': _serviceCategory,
        'odometer': odometerValue,
        'cost': costValue,
        'performed_by': performedBy.isNotEmpty ? performedBy : null,
        'notes': notes.isNotEmpty ? notes : null,
      });

      await _loadServiceEvents();
      if (mounted) {
        Navigator.of(context).pop(); // close dialog
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
        _savingEvent = false;
      });
    }
  }

  Future<void> _deleteServiceEvent(String id) async {
    try {
      await supabase.from('service_events').delete().eq('id', id);
      await _loadServiceEvents();
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

  void _showServiceEventDetails(Map<String, dynamic> e) {
    final category = e['category'] as String? ?? 'Service';
    final dateStr = _formatDate(e['service_date'] as String?);
    final odo = e['odometer'] as num?;
    final cost = e['cost'] as num?;
    final performedBy = e['performed_by'] as String?;
    final notes = e['notes'] as String?;
    final id = e['id'] as String?;

    String odoText = 'Odometer: not recorded';
    if (odo != null) {
      odoText = 'Odometer: ${odo.toInt()}';
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(category),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Date: $dateStr',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  odoText,
                  style: const TextStyle(fontSize: 13),
                ),
                if (cost != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Cost: ${_formatCurrency(cost)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
                if (performedBy != null && performedBy.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Performed by: $performedBy',
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
            if (id != null)
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop(); // close details dialog
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('Delete service event?'),
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
                    await _deleteServiceEvent(id);
                  }
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // ====== VEHICLE HEADER / EDIT / DELETE ======

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

  Widget _buildVehicleHeader(BuildContext context) {
    final v = _vehicleData;
    final name = v['name'] as String? ?? 'Vehicle';
    final year = v['year']?.toString();
    final make = v['make'] as String?;
    final model = v['model'] as String?;
    final trim = v['trim'] as String?;
    final type = v['vehicle_type'] as String? ?? '';
    final currentOdo = v['current_odometer'] as num?;
    final unit = v['odometer_unit'] as String? ?? 'mi';

    final subtitleParts = <String>[];
    if (year != null && year.isNotEmpty) subtitleParts.add(year);
    if (make != null && make.isNotEmpty) subtitleParts.add(make);
    if (model != null && model.isNotEmpty) subtitleParts.add(model);
    if (trim != null && trim.isNotEmpty) subtitleParts.add(trim);
    final subtitle = subtitleParts.join(' ');

    String typeLabel = _vehicleTypeLabel(type);

    String odoText;
    if (currentOdo != null) {
      odoText = '${currentOdo.toInt()} $unit';
    } else {
      odoText = 'Odometer not set';
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
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
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
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
                  const SizedBox(height: 4),
                  Text(
                    'Odometer: $odoText',
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
    );
  }

  void _showEditVehicleDialog() {
    final v = _vehicleData;

    String name = v['name'] as String? ?? '';
    String vehicleType = (v['vehicle_type'] as String?) ?? 'car';
    String year = v['year']?.toString() ?? '';
    String make = v['make'] as String? ?? '';
    String model = v['model'] as String? ?? '';
    String trim = v['trim'] as String? ?? '';
    String odo = v['current_odometer'] != null
        ? (v['current_odometer'] as num).toInt().toString()
        : '';
    String unit = (v['odometer_unit'] as String?) ?? 'mi';
    String notes = v['notes'] as String? ?? '';

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
                await supabase
                    .from('vehicles')
                    .update({
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
                    })
                    .eq('id', widget.vehicle['id']);

                if (context.mounted) {
                  Navigator.of(context).pop();
                }
                await _loadVehicleRow();
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
              title: const Text('Edit vehicle'),
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
                      onChanged: (vType) {
                        if (vType == null) return;
                        setLocalState(() => vehicleType = vType);
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
                          onChanged: (vUnit) {
                            if (vUnit == null) return;
                            setLocalState(() => unit = vUnit);
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

  Future<void> _deleteVehicle() async {
    final vehicleId = widget.vehicle['id'] as String?;
    if (vehicleId == null) return;

    try {
      // Clean up related data first (if no ON DELETE CASCADE)
      await supabase
          .from('service_events')
          .delete()
          .eq('vehicle_id', vehicleId);
      await supabase
          .from('reminders')
          .delete()
          .eq('vehicle_id', vehicleId);
      await supabase
          .from('device_links')
          .delete()
          .eq('vehicle_id', vehicleId);
      await supabase
          .from('telemetry_events')
          .delete()
          .eq('vehicle_id', vehicleId);

      await supabase.from('vehicles').delete().eq('id', vehicleId);

      if (mounted) {
        Navigator.of(context).pop(); // pop details page
      }
    } on PostgrestException catch (e) {
      setState(() {
        _errorText = e.message;
      });
    } catch (e) {
      setState(() {
        _errorText = 'Unexpected error deleting vehicle: $e';
      });
    }
  }

  Future<void> _confirmDeleteVehicle() async {
    final v = _vehicleData;
    final name = v['name'] as String? ?? 'this vehicle';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete vehicle?'),
          content: Text(
            'Delete "$name" and all its service history, reminders, devices, and telemetry? '
            'This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
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
      await _deleteVehicle();
    }
  }

  // ====== IOT SECTION ======

  String _deviceTypeLabel(String type) {
    switch (type) {
      case 'obd':
        return 'OBD device';
      case 'battery_monitor':
        return 'Battery monitor';
      case 'tracker':
        return 'Tracker';
      default:
        return 'Other device';
    }
  }

  Future<void> _showLinkDeviceDialog() async {
    final vehicleId = widget.vehicle['id'] as String?;
    if (vehicleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vehicle ID missing.')),
      );
      return;
    }

    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No user logged in.')),
      );
      return;
    }

    String deviceType = 'obd';
    final deviceIdController = TextEditingController();
    final nicknameController = TextEditingController();
    bool saving = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            Future<void> save() async {
              if (saving) return;

              final deviceId = deviceIdController.text.trim();
              if (deviceId.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Device ID is required.'),
                  ),
                );
                return;
              }

              setLocalState(() => saving = true);

              try {
                await supabase.from('device_links').insert({
                  'user_id': user.id,
                  'vehicle_id': vehicleId,
                  'device_id': deviceId,
                  'device_type': deviceType,
                  'nickname': nicknameController.text.trim().isNotEmpty
                      ? nicknameController.text.trim()
                      : null,
                });

                if (context.mounted) {
                  Navigator.of(context).pop();
                }
                await _loadIoTData();
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
              title: const Text('Link device'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: deviceType,
                      decoration: const InputDecoration(
                        labelText: 'Device type',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'obd',
                          child: Text('OBD / telematics'),
                        ),
                        DropdownMenuItem(
                          value: 'battery_monitor',
                          child: Text('Battery monitor'),
                        ),
                        DropdownMenuItem(
                          value: 'tracker',
                          child: Text('GPS tracker'),
                        ),
                        DropdownMenuItem(
                          value: 'other',
                          child: Text('Other'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setLocalState(() => deviceType = v);
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: deviceIdController,
                      decoration: const InputDecoration(
                        labelText: 'Device ID',
                        hintText: 'Serial, BLE MAC, or external ID',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nicknameController,
                      decoration: const InputDecoration(
                        labelText: 'Nickname (optional)',
                        hintText: 'e.g. Cart battery sensor',
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

  Widget _buildIoTSection() {
    final hasDevices = _deviceLinks.isNotEmpty;
    final latest = _latestTelemetry;

    if (!hasDevices && latest == null && !_iotLoading) {
      return Card(
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
              const Icon(
                Icons.sensors,
                size: 22,
                color: Colors.grey,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Devices & telemetry',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'No devices linked yet. Link an OBD, battery monitor, or tracker to start pulling automatic data.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: _showLinkDeviceDialog,
                        icon: const Icon(
                          Icons.add_link,
                          size: 16,
                        ),
                        label: const Text(
                          'Link device',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.sensors,
                  size: 22,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Devices & telemetry',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Refresh',
                  iconSize: 18,
                  onPressed: _loadIoTData,
                  icon: const Icon(Icons.refresh),
                ),
                OutlinedButton.icon(
                  onPressed: _showLinkDeviceDialog,
                  icon: const Icon(
                    Icons.add_link,
                    size: 16,
                  ),
                  label: const Text(
                    'Link',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            if (_iotLoading) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(minHeight: 2),
            ],
            if (hasDevices) ...[
              const SizedBox(height: 8),
              const Text(
                'Linked devices',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              ..._deviceLinks.map((d) {
                final type = d['device_type'] as String? ?? 'other';
                final deviceId = d['device_id'] as String? ?? '';
                final nickname = d['nickname'] as String?;
                final label = _deviceTypeLabel(type);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.memory,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nickname?.isNotEmpty == true
                                  ? nickname!
                                  : label,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'ID: $deviceId',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            if (latest != null) ...[
              const SizedBox(height: 10),
              const Divider(height: 16),
              const Text(
                'Latest telemetry',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Builder(
                builder: (_) {
                  final recordedAt =
                      _formatDateTime(latest['recorded_at'] as String?);
                  final odo = latest['odometer'] as num?;
                  final batterySoc = latest['battery_soc'] as num?;
                  final batteryVoltage =
                      latest['battery_voltage'] as num?;
                  final lat = latest['latitude'] as num?;
                  final lng = latest['longitude'] as num?;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Last seen: $recordedAt',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      if (odo != null)
                        Text(
                          'Odometer: ${odo.toInt()}',
                          style: const TextStyle(
                            fontSize: 12,
                          ),
                        ),
                      if (batterySoc != null)
                        Text(
                          'Battery: ${batterySoc.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 12,
                          ),
                        ),
                      if (batteryVoltage != null)
                        Text(
                          'Voltage: ${batteryVoltage.toStringAsFixed(1)} V',
                          style: const TextStyle(
                            fontSize: 12,
                          ),
                        ),
                      if (lat != null && lng != null)
                        Text(
                          'Location: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                          style: const TextStyle(
                            fontSize: 12,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ====== SERVICE LIST ======

  Widget _buildServiceList() {
    if (_serviceEvents.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          'No service history yet. Add your first service event to keep track of maintenance.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey,
          ),
        ),
      );
    }

    return Column(
      children: _serviceEvents.map((e) {
        final category = e['category'] as String? ?? 'Service';
        final dateStr = _formatDate(e['service_date'] as String?);
        final odo = e['odometer'] as num?;
        final cost = e['cost'] as num?;

        String odoText = 'Odometer not recorded';
        if (odo != null) {
          odoText = 'Odometer: ${odo.toInt()}';
        }

        return InkWell(
          onTap: () => _showServiceEventDetails(e),
          borderRadius: BorderRadius.circular(12),
          child: Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        category,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    odoText,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  if (cost != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Cost: ${_formatCurrency(cost)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
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
    final name =
        _vehicleData['name'] as String? ?? 'Vehicle details';

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
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
                  builder: (_) => RemindersPage(
                    vehicle: _vehicleData,
                  ),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                _showEditVehicleDialog();
              } else if (value == 'delete') {
                _confirmDeleteVehicle();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Text('Edit vehicle'),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Delete vehicle',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadVehicleRow();
          await _loadServiceEvents();
          await _loadIoTData();
        },
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    _buildVehicleHeader(context),
                    const SizedBox(height: 8),
                    _buildIoTSection(),
                    const SizedBox(height: 8),
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
                          'Service history',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _showAddServiceEventDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _buildServiceList(),
                  ],
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddServiceEventDialog,
        icon: const Icon(Icons.add_task),
        label: const Text('Add service'),
      ),
    );
  }
}
