import '../constants/app_constants.dart';
import 'base_service.dart';

/// Service for managing vehicle data and operations
class VehicleService extends BaseService {
  /// Fetches all vehicles for the current user
  Future<List<Map<String, dynamic>>> getVehicles() async {
    requireAuth();

    final response = await supabase
        .from(DbTables.vehicles)
        .select()
        .eq('user_id', currentUserId!)
        .order('created_at');

    return List<Map<String, dynamic>>.from(response);
  }

  /// Fetches a single vehicle by ID
  Future<Map<String, dynamic>?> getVehicle(String vehicleId) async {
    requireAuth();

    final response = await supabase
        .from(DbTables.vehicles)
        .select()
        .eq('id', vehicleId)
        .eq('user_id', currentUserId!)
        .maybeSingle();

    return response;
  }

  /// Creates a new vehicle
  Future<Map<String, dynamic>> createVehicle({
    required String name,
    required String vehicleType,
    String? year,
    String? make,
    String? model,
    String? trim,
    num? currentOdometer,
    String? odometerUnit,
    String? notes,
  }) async {
    requireAuth();

    final data = {
      'user_id': currentUserId,
      'name': name,
      'vehicle_type': vehicleType,
      'year': year,
      'make': make,
      'model': model,
      'trim': trim,
      'current_odometer': currentOdometer,
      'odometer_unit': odometerUnit ?? OdometerUnits.miles,
      'notes': notes,
    };

    final response = await supabase
        .from(DbTables.vehicles)
        .insert(data)
        .select()
        .single();

    return response;
  }

  /// Updates an existing vehicle
  Future<Map<String, dynamic>> updateVehicle(
    String vehicleId,
    Map<String, dynamic> updates,
  ) async {
    requireAuth();

    final response = await supabase
        .from(DbTables.vehicles)
        .update(updates)
        .eq('id', vehicleId)
        .eq('user_id', currentUserId!)
        .select()
        .single();

    return response;
  }

  /// Updates the odometer reading for a vehicle
  Future<void> updateOdometer(String vehicleId, num odometer) async {
    requireAuth();

    await supabase
        .from(DbTables.vehicles)
        .update({'current_odometer': odometer})
        .eq('id', vehicleId)
        .eq('user_id', currentUserId!);
  }

  /// Deletes a vehicle and all associated data
  /// This will cascade delete reminders, service events, device links, and telemetry
  Future<void> deleteVehicle(String vehicleId) async {
    requireAuth();

    // Delete associated data first
    await Future.wait([
      supabase
          .from(DbTables.reminders)
          .delete()
          .eq('vehicle_id', vehicleId)
          .eq('user_id', currentUserId!),
      supabase
          .from(DbTables.serviceEvents)
          .delete()
          .eq('vehicle_id', vehicleId)
          .eq('user_id', currentUserId!),
      supabase
          .from(DbTables.telemetryEvents)
          .delete()
          .eq('vehicle_id', vehicleId)
          .eq('user_id', currentUserId!),
      supabase
          .from(DbTables.deviceLinks)
          .delete()
          .eq('vehicle_id', vehicleId)
          .eq('user_id', currentUserId!),
    ]);

    // Then delete the vehicle
    await supabase
        .from(DbTables.vehicles)
        .delete()
        .eq('id', vehicleId)
        .eq('user_id', currentUserId!);
  }

  /// Gets the count of vehicles for the current user
  Future<int> getVehicleCount() async {
    requireAuth();

    final response = await supabase
        .from(DbTables.vehicles)
        .select('id')
        .eq('user_id', currentUserId!);

    return response.length;
  }

  /// Gets vehicles with linked IoT devices
  Future<List<Map<String, dynamic>>> getVehiclesWithDevices() async {
    requireAuth();

    final vehicles = await getVehicles();
    final vehiclesWithDevices = <Map<String, dynamic>>[];

    for (final vehicle in vehicles) {
      final devices = await supabase
          .from(DbTables.deviceLinks)
          .select()
          .eq('vehicle_id', vehicle['id'])
          .eq('user_id', currentUserId!);

      if (devices.isNotEmpty) {
        vehiclesWithDevices.add(vehicle);
      }
    }

    return vehiclesWithDevices;
  }
}
