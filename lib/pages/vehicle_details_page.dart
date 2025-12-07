import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../services/auth_service.dart';
import '../services/vehicle_service.dart';
import '../services/service_event_service.dart';
import '../services/device_service.dart';
import '../services/reminder_service.dart';
import '../utils/date_helpers.dart';
import '../utils/number_helpers.dart';
import '../utils/validation_helpers.dart';
import 'reminders_page.dart';
import 'dashboard_page.dart';

class VehicleDetailsPage extends StatefulWidget {
  final Map<String, dynamic> vehicle;

  const VehicleDetailsPage({super.key, required this.vehicle});

  @override
  State<VehicleDetailsPage> createState() => _VehicleDetailsPageState();
}

class _VehicleDetailsPageState extends State<VehicleDetailsPage> {
  final _vehicleService = VehicleService();
  final _serviceEventService = ServiceEventService();
  final _deviceService = DeviceService();
  final _authService = AuthService();

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

  Map<String, dynamic> get _vehicleData => _vehicleRow ?? widget.vehicle;

  Future<void> _loadVehicleRow() async {
    final vehicleId = widget.vehicle['id'] as String?;
    if (vehicleId == null) return;

    try {
      final vehicle = await _vehicleService.getVehicle(vehicleId);
      if (vehicle != null && mounted) {
        setState(() {
          _vehicleRow = vehicle;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText ??= 'Error loading vehicle: $e';
        });
      }
    }
  }

  Future<void> _loadServiceEvents() async {
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
            _serviceEvents = [];
          });
        }
        return;
      }

      final events = await _serviceEventService.getServiceEventsForVehicle(vehicleId);
      if (mounted) {
        setState(() {
          _serviceEvents = events;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = 'Error loading service events: $e';
          _serviceEvents = [];
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

  Future<void> _loadIoTData() async {
    final vehicleId = widget.vehicle['id'] as String?;
    if (vehicleId == null) {
      if (mounted) {
        setState(() {
          _deviceLinks = [];
          _latestTelemetry = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _iotLoading = true;
      });
    }

    try {
      final user = _authService.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _deviceLinks = [];
            _latestTelemetry = null;
          });
        }
        return;
      }

      // Device links for this vehicle
      final links = await _deviceService.getDeviceLinksForVehicle(vehicleId);

      // Latest telemetry event for this vehicle
      final telemetry = await _deviceService.getLatestTelemetry(vehicleId);

      if (mounted) {
        setState(() {
          _deviceLinks = links;
          _latestTelemetry = telemetry;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText ??= 'Error loading IoT data: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _iotLoading = false;
        });
      }
    }
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

            final dateLabel = DateHelpers.formatDate(_serviceDate.toIso8601String());

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
                    SizedBox(height: UiConstants.spacingSmall),
                    DropdownButtonFormField<String>(
                      initialValue: _serviceCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                      ),
                      items: MaintenanceCategories.getDropdownItems(),
                      onChanged: (value) {
                        if (value == null) return;
                        setLocalState(() {
                          _serviceCategory = value;
                        });
                      },
                    ),
                    SizedBox(height: UiConstants.spacingSmall),
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
                            'Use latest from device (${NumberHelpers.formatOdometer(latest['odometer'] as num?, _vehicleRow?['odometer_unit'] as String? ?? OdometerUnits.miles)})',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Last reading: ${DateHelpers.formatDate(latest['recorded_at'] as String?)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                    SizedBox(height: UiConstants.spacingSmall),
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
                    SizedBox(height: UiConstants.spacingSmall),
                    TextField(
                      controller: _performedByController,
                      decoration: const InputDecoration(
                        labelText: 'Performed by (optional)',
                        hintText: 'Self or shop name',
                      ),
                    ),
                    SizedBox(height: UiConstants.spacingSmall),
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

    final odoText = _odometerController.text.trim();
    final costText = _costController.text.trim();
    final performedBy = _performedByController.text.trim();
    final notes = _notesController.text.trim();

    // Validate odometer
    if (odoText.isNotEmpty) {
      final error = ValidationHelpers.validateOdometer(odoText);
      if (error != null) {
        if (mounted) {
          setState(() {
            _errorText = error;
          });
        }
        return;
      }
    }

    // Validate cost
    if (costText.isNotEmpty) {
      final error = ValidationHelpers.validateCost(costText);
      if (error != null) {
        if (mounted) {
          setState(() {
            _errorText = error;
          });
        }
        return;
      }
    }

    // Parse values
    int? odometerValue;
    if (odoText.isNotEmpty) {
      odometerValue = NumberHelpers.parseNumber(odoText)?.toInt();
    }

    num? costValue;
    if (costText.isNotEmpty) {
      costValue = NumberHelpers.parseNumber(costText);
    }

    if (mounted) {
      setState(() {
        _savingEvent = true;
        _errorText = null;
      });
    }

    try {
      await _serviceEventService.createServiceEvent(
        vehicleId: vehicleId,
        serviceDate: _serviceDate.toIso8601String(),
        category: _serviceCategory,
        odometer: odometerValue,
        cost: costValue,
        performedBy: performedBy.isNotEmpty ? performedBy : null,
        notes: notes.isNotEmpty ? notes : null,
      );

      await _loadServiceEvents();
      if (mounted) {
        Navigator.of(context).pop(); // close dialog
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = 'Error saving service event: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _savingEvent = false;
        });
      }
    }
  }

  Future<void> _deleteServiceEvent(String id) async {
    try {
      await _serviceEventService.deleteServiceEvent(id);
      await _loadServiceEvents();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = 'Error deleting service event: $e';
        });
      }
    }
  }

  void _showServiceEventDetails(Map<String, dynamic> e) {
    final category = e['category'] as String? ?? 'Service';
    final dateStr = DateHelpers.formatDate(e['service_date'] as String?);
    final odo = e['odometer'] as num?;
    final cost = e['cost'] as num?;
    final performedBy = e['performed_by'] as String?;
    final notes = e['notes'] as String?;
    final id = e['id'] as String?;

    final unit = _vehicleRow?['odometer_unit'] as String? ?? OdometerUnits.miles;
    String odoText = 'Odometer: not recorded';
    if (odo != null) {
      odoText = 'Odometer: ${NumberHelpers.formatOdometer(odo, unit)}';
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
                    'Cost: ${NumberHelpers.formatCurrency(cost)}',
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

  Widget _buildVehicleHeader(BuildContext context) {
    final v = _vehicleData;
    final name = v['name'] as String? ?? 'Vehicle';
    final year = v['year']?.toString();
    final make = v['make'] as String?;
    final model = v['model'] as String?;
    final trim = v['trim'] as String?;
    final type = v['vehicle_type'] as String? ?? '';
    final currentOdo = v['current_odometer'] as num?;
    final unit = v['odometer_unit'] as String? ?? OdometerUnits.miles;

    final subtitleParts = <String>[];
    if (year != null && year.isNotEmpty) subtitleParts.add(year);
    if (make != null && make.isNotEmpty) subtitleParts.add(make);
    if (model != null && model.isNotEmpty) subtitleParts.add(model);
    if (trim != null && trim.isNotEmpty) subtitleParts.add(trim);
    final subtitle = subtitleParts.join(' ');

    String typeLabel = VehicleTypes.getLabel(type);

    String odoText;
    if (currentOdo != null) {
      odoText = NumberHelpers.formatOdometer(currentOdo, unit);
    } else {
      odoText = 'Odometer not set';
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UiConstants.borderRadiusMedium),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Padding(
        padding: EdgeInsets.all(UiConstants.spacingMedium - 2),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              child: Icon(
                Icons.directions_car,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            SizedBox(width: UiConstants.spacingMedium - 4),
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
    String unit = (v['odometer_unit'] as String?) ?? OdometerUnits.miles;
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

              // Validate required fields
              final nameError = ValidationHelpers.validateRequired(vName, 'Vehicle name');
              if (nameError != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(nameError)),
                );
                return;
              }

              // Validate odometer if provided
              if (odoController.text.trim().isNotEmpty) {
                final odoError = ValidationHelpers.validateOdometer(odoController.text.trim());
                if (odoError != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(odoError)),
                  );
                  return;
                }
              }

              int? yearInt;
              if (yearController.text.trim().isNotEmpty) {
                yearInt = int.tryParse(yearController.text.trim());
              }
              num? odoNum;
              if (odoController.text.trim().isNotEmpty) {
                odoNum = NumberHelpers.parseNumber(odoController.text.trim());
              }

              setLocalState(() => saving = true);

              try {
                final updates = <String, dynamic>{
                  'name': vName,
                  'vehicle_type': vehicleType,
                  'year': yearInt?.toString(),
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
                };

                await _vehicleService.updateVehicle(
                  widget.vehicle['id'] as String,
                  updates,
                );

                if (context.mounted) {
                  Navigator.of(context).pop();
                }
                await _loadVehicleRow();
              } catch (e) {
                setLocalState(() => saving = false);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
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
                    SizedBox(height: UiConstants.spacingSmall),
                    DropdownButtonFormField<String>(
                      initialValue: vehicleType,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                      ),
                      items: VehicleTypes.getDropdownItems(),
                      onChanged: (vType) {
                        if (vType == null) return;
                        setLocalState(() => vehicleType = vType);
                      },
                    ),
                    SizedBox(height: UiConstants.spacingSmall),
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
                        SizedBox(width: UiConstants.spacingSmall),
                        Expanded(
                          child: TextField(
                            controller: makeController,
                            decoration: const InputDecoration(
                              labelText: 'Make',
                            ),
                          ),
                        ),
                        SizedBox(width: UiConstants.spacingSmall),
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
                    SizedBox(height: UiConstants.spacingSmall),
                    TextField(
                      controller: trimController,
                      decoration: const InputDecoration(
                        labelText: 'Trim (optional)',
                      ),
                    ),
                    SizedBox(height: UiConstants.spacingSmall),
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
                        SizedBox(width: UiConstants.spacingSmall),
                        DropdownButton<String>(
                          value: unit,
                          items: const [
                            DropdownMenuItem(
                              value: OdometerUnits.miles,
                              child: Text(OdometerUnits.miles),
                            ),
                            DropdownMenuItem(
                              value: OdometerUnits.kilometers,
                              child: Text(OdometerUnits.kilometers),
                            ),
                          ],
                          onChanged: (vUnit) {
                            if (vUnit == null) return;
                            setLocalState(() => unit = vUnit);
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: UiConstants.spacingSmall),
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
      await _vehicleService.deleteVehicle(vehicleId);

      if (mounted) {
        Navigator.of(context).pop(); // pop details page
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = 'Error deleting vehicle: $e';
        });
      }
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

  Future<void> _showLinkDeviceDialog() async {
    final vehicleId = widget.vehicle['id'] as String?;
    if (vehicleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vehicle ID missing.')),
      );
      return;
    }

    final user = _authService.currentUser;
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

              // Validate required field
              final error = ValidationHelpers.validateRequired(deviceId, 'Device ID');
              if (error != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error)),
                );
                return;
              }

              setLocalState(() => saving = true);

              try {
                await _deviceService.createDeviceLink(
                  vehicleId: vehicleId,
                  deviceId: deviceId,
                  deviceType: deviceType,
                  nickname: nicknameController.text.trim().isNotEmpty
                      ? nicknameController.text.trim()
                      : null,
                );

                if (context.mounted) {
                  Navigator.of(context).pop();
                }
                await _loadIoTData();
              } catch (e) {
                setLocalState(() => saving = false);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            }

            return AlertDialog(
              title: const Text('Link device'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: deviceType,
                      decoration: const InputDecoration(
                        labelText: 'Device type',
                      ),
                      items: DeviceTypes.getDropdownItems(),
                      onChanged: (v) {
                        if (v == null) return;
                        setLocalState(() => deviceType = v);
                      },
                    ),
                    SizedBox(height: UiConstants.spacingSmall),
                    TextField(
                      controller: deviceIdController,
                      decoration: const InputDecoration(
                        labelText: 'Device ID',
                        hintText: 'Serial, BLE MAC, or external ID',
                      ),
                    ),
                    SizedBox(height: UiConstants.spacingSmall),
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
          borderRadius: BorderRadius.circular(UiConstants.borderRadiusMedium),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Padding(
          padding: EdgeInsets.all(UiConstants.spacingMedium - 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.sensors,
                size: 22,
                color: Colors.grey,
              ),
              SizedBox(width: UiConstants.spacingSmall + 2),
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
                    SizedBox(height: UiConstants.spacingSmall),
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
        borderRadius: BorderRadius.circular(UiConstants.borderRadiusMedium),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Padding(
        padding: EdgeInsets.all(UiConstants.spacingMedium - 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.sensors,
                  size: 22,
                ),
                SizedBox(width: UiConstants.spacingSmall),
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
              SizedBox(height: UiConstants.spacingSmall),
              const LinearProgressIndicator(minHeight: 2),
            ],
            if (hasDevices) ...[
              SizedBox(height: UiConstants.spacingSmall),
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
                final label = DeviceTypes.getLabel(type);
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
              SizedBox(height: UiConstants.spacingSmall + 2),
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
                  final recordedAt = DateHelpers.formatDate(
                    latest['recorded_at'] as String?,
                  );
                  final odo = latest['odometer'] as num?;
                  final batterySoc = latest['battery_soc'] as num?;
                  final batteryVoltage = latest['battery_voltage'] as num?;
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
                          'Odometer: ${NumberHelpers.formatOdometer(odo, _vehicleRow?['odometer_unit'] as String? ?? OdometerUnits.miles)}',
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
      return Padding(
        padding: EdgeInsets.all(UiConstants.spacingMedium - 4),
        child: const Text(
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
        final dateStr = DateHelpers.formatDate(e['service_date'] as String?);
        final odo = e['odometer'] as num?;
        final cost = e['cost'] as num?;

        final unit = _vehicleRow?['odometer_unit'] as String? ?? OdometerUnits.miles;
        String odoText = 'Odometer not recorded';
        if (odo != null) {
          odoText = 'Odometer: ${NumberHelpers.formatOdometer(odo, unit)}';
        }

        return InkWell(
          onTap: () => _showServiceEventDetails(e),
          borderRadius: BorderRadius.circular(UiConstants.borderRadiusMedium),
          child: Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(UiConstants.borderRadiusMedium),
            ),
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Padding(
              padding: EdgeInsets.all(UiConstants.spacingMedium - 4),
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
                      'Cost: ${NumberHelpers.formatCurrency(cost)}',
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
    final name = _vehicleData['name'] as String? ?? 'Vehicle details';

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
                  padding: EdgeInsets.all(UiConstants.spacingMedium - 4),
                  children: [
                    _buildVehicleHeader(context),
                    SizedBox(height: UiConstants.spacingSmall),
                    _buildIoTSection(),
                    SizedBox(height: UiConstants.spacingSmall),
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
