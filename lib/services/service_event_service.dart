import '../constants/app_constants.dart';
import 'base_service.dart';

/// Service for managing vehicle service events and history
class ServiceEventService extends BaseService {
  /// Fetches all service events for the current user
  Future<List<Map<String, dynamic>>> getServiceEvents() async {
    requireAuth();

    final response = await supabase
        .from(DbTables.serviceEvents)
        .select()
        .eq('user_id', currentUserId!)
        .order('service_date', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Fetches service events for a specific vehicle
  Future<List<Map<String, dynamic>>> getServiceEventsForVehicle(
    String vehicleId,
  ) async {
    requireAuth();

    final response = await supabase
        .from(DbTables.serviceEvents)
        .select()
        .eq('vehicle_id', vehicleId)
        .eq('user_id', currentUserId!)
        .order('service_date', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Fetches a single service event by ID
  Future<Map<String, dynamic>?> getServiceEvent(String eventId) async {
    requireAuth();

    final response = await supabase
        .from(DbTables.serviceEvents)
        .select()
        .eq('id', eventId)
        .eq('user_id', currentUserId!)
        .maybeSingle();

    return response;
  }

  /// Creates a new service event
  Future<Map<String, dynamic>> createServiceEvent({
    required String vehicleId,
    required String serviceDate,
    required String category,
    num? odometer,
    num? cost,
    String? performedBy,
    String? notes,
  }) async {
    requireAuth();

    final data = {
      'user_id': currentUserId,
      'vehicle_id': vehicleId,
      'service_date': serviceDate,
      'category': category,
      'odometer': odometer,
      'cost': cost,
      'performed_by': performedBy,
      'notes': notes,
    };

    final response = await supabase
        .from(DbTables.serviceEvents)
        .insert(data)
        .select()
        .single();

    return response;
  }

  /// Updates an existing service event
  Future<Map<String, dynamic>> updateServiceEvent(
    String eventId,
    Map<String, dynamic> updates,
  ) async {
    requireAuth();

    final response = await supabase
        .from(DbTables.serviceEvents)
        .update(updates)
        .eq('id', eventId)
        .eq('user_id', currentUserId!)
        .select()
        .single();

    return response;
  }

  /// Deletes a service event
  Future<void> deleteServiceEvent(String eventId) async {
    requireAuth();

    await supabase
        .from(DbTables.serviceEvents)
        .delete()
        .eq('id', eventId)
        .eq('user_id', currentUserId!);
  }

  /// Gets the most recent service event for a vehicle
  Future<Map<String, dynamic>?> getMostRecentServiceEvent(
    String vehicleId,
  ) async {
    requireAuth();

    final response = await supabase
        .from(DbTables.serviceEvents)
        .select()
        .eq('vehicle_id', vehicleId)
        .eq('user_id', currentUserId!)
        .order('service_date', ascending: false)
        .limit(1)
        .maybeSingle();

    return response;
  }

  /// Gets service events by category for a vehicle
  Future<List<Map<String, dynamic>>> getServiceEventsByCategory(
    String vehicleId,
    String category,
  ) async {
    requireAuth();

    final response = await supabase
        .from(DbTables.serviceEvents)
        .select()
        .eq('vehicle_id', vehicleId)
        .eq('user_id', currentUserId!)
        .eq('category', category)
        .order('service_date', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Gets the total service cost for a vehicle
  Future<num> getTotalServiceCost(String vehicleId) async {
    requireAuth();

    final events = await getServiceEventsForVehicle(vehicleId);
    num total = 0;

    for (final event in events) {
      final cost = event['cost'] as num?;
      if (cost != null) {
        total += cost;
      }
    }

    return total;
  }

  /// Gets service event count for a vehicle
  Future<int> getServiceEventCount(String vehicleId) async {
    requireAuth();

    final response = await supabase
        .from(DbTables.serviceEvents)
        .select('id')
        .eq('vehicle_id', vehicleId)
        .eq('user_id', currentUserId!);

    return response.length;
  }

  /// Creates a quick "Charge rotation" service event for golf carts
  Future<Map<String, dynamic>> createChargeRotationEvent({
    required String vehicleId,
    String? serviceDate,
  }) async {
    final date = serviceDate ?? DateTime.now().toIso8601String();

    return await createServiceEvent(
      vehicleId: vehicleId,
      serviceDate: date,
      category: MaintenanceCategories.chargeRotation,
      performedBy: 'Self',
    );
  }
}
