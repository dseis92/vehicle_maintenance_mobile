import '../constants/app_constants.dart';
import 'base_service.dart';

/// Service for managing IoT device links and telemetry
class DeviceService extends BaseService {
  /// Fetches all device links for the current user
  Future<List<Map<String, dynamic>>> getDeviceLinks() async {
    requireAuth();

    final response = await supabase
        .from(DbTables.deviceLinks)
        .select()
        .eq('user_id', currentUserId!)
        .order('created_at');

    return List<Map<String, dynamic>>.from(response);
  }

  /// Fetches device links for a specific vehicle
  Future<List<Map<String, dynamic>>> getDeviceLinksForVehicle(
    String vehicleId,
  ) async {
    requireAuth();

    final response = await supabase
        .from(DbTables.deviceLinks)
        .select()
        .eq('vehicle_id', vehicleId)
        .eq('user_id', currentUserId!)
        .order('created_at');

    return List<Map<String, dynamic>>.from(response);
  }

  /// Fetches a single device link by ID
  Future<Map<String, dynamic>?> getDeviceLink(String linkId) async {
    requireAuth();

    final response = await supabase
        .from(DbTables.deviceLinks)
        .select()
        .eq('id', linkId)
        .eq('user_id', currentUserId!)
        .maybeSingle();

    return response;
  }

  /// Creates a new device link
  Future<Map<String, dynamic>> createDeviceLink({
    required String vehicleId,
    required String deviceId,
    required String deviceType,
    String? nickname,
  }) async {
    requireAuth();

    final data = {
      'user_id': currentUserId,
      'vehicle_id': vehicleId,
      'device_id': deviceId,
      'device_type': deviceType,
      'nickname': nickname,
    };

    final response = await supabase
        .from(DbTables.deviceLinks)
        .insert(data)
        .select()
        .single();

    return response;
  }

  /// Updates an existing device link
  Future<Map<String, dynamic>> updateDeviceLink(
    String linkId,
    Map<String, dynamic> updates,
  ) async {
    requireAuth();

    final response = await supabase
        .from(DbTables.deviceLinks)
        .update(updates)
        .eq('id', linkId)
        .eq('user_id', currentUserId!)
        .select()
        .single();

    return response;
  }

  /// Deletes a device link
  Future<void> deleteDeviceLink(String linkId) async {
    requireAuth();

    await supabase
        .from(DbTables.deviceLinks)
        .delete()
        .eq('id', linkId)
        .eq('user_id', currentUserId!);
  }

  /// Gets the latest telemetry for a device
  Future<Map<String, dynamic>?> getLatestTelemetry(String deviceId) async {
    requireAuth();

    final response = await supabase
        .from(DbTables.telemetryEvents)
        .select()
        .eq('device_id', deviceId)
        .eq('user_id', currentUserId!)
        .order('recorded_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return response;
  }

  /// Gets telemetry events for a device
  Future<List<Map<String, dynamic>>> getTelemetryForDevice(
    String deviceId, {
    int limit = 100,
  }) async {
    requireAuth();

    final response = await supabase
        .from(DbTables.telemetryEvents)
        .select()
        .eq('device_id', deviceId)
        .eq('user_id', currentUserId!)
        .order('recorded_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Gets telemetry events for a vehicle
  Future<List<Map<String, dynamic>>> getTelemetryForVehicle(
    String vehicleId, {
    int limit = 100,
  }) async {
    requireAuth();

    final response = await supabase
        .from(DbTables.telemetryEvents)
        .select()
        .eq('vehicle_id', vehicleId)
        .eq('user_id', currentUserId!)
        .order('recorded_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Creates a new telemetry event
  Future<Map<String, dynamic>> createTelemetryEvent({
    required String vehicleId,
    required String deviceId,
    required String recordedAt,
    num? odometer,
    num? batterySoc,
    num? batteryVoltage,
    num? latitude,
    num? longitude,
  }) async {
    requireAuth();

    final data = {
      'user_id': currentUserId,
      'vehicle_id': vehicleId,
      'device_id': deviceId,
      'recorded_at': recordedAt,
      'odometer': odometer,
      'battery_soc': batterySoc,
      'battery_voltage': batteryVoltage,
      'latitude': latitude,
      'longitude': longitude,
    };

    final response = await supabase
        .from(DbTables.telemetryEvents)
        .insert(data)
        .select()
        .single();

    return response;
  }

  /// Checks if a device has stale telemetry (older than threshold)
  Future<bool> isDeviceStale(String deviceId) async {
    final latest = await getLatestTelemetry(deviceId);
    if (latest == null) return true;

    final recordedAtStr = latest['recorded_at'] as String?;
    if (recordedAtStr == null) return true;

    try {
      final recordedAt = DateTime.parse(recordedAtStr);
      final now = DateTime.now();
      final hoursSince = now.difference(recordedAt).inHours;

      return hoursSince > AppThresholds.staleDeviceHours;
    } catch (_) {
      return true;
    }
  }

  /// Gets count of stale devices for the current user
  Future<int> getStaleDeviceCount() async {
    requireAuth();

    final devices = await getDeviceLinks();
    int staleCount = 0;

    for (final device in devices) {
      final deviceId = device['device_id'] as String?;
      if (deviceId != null && await isDeviceStale(deviceId)) {
        staleCount++;
      }
    }

    return staleCount;
  }

  /// Gets count of devices with active telemetry
  Future<int> getActiveDeviceCount() async {
    requireAuth();

    final devices = await getDeviceLinks();
    int activeCount = 0;

    for (final device in devices) {
      final deviceId = device['device_id'] as String?;
      if (deviceId != null && !await isDeviceStale(deviceId)) {
        activeCount++;
      }
    }

    return activeCount;
  }
}
