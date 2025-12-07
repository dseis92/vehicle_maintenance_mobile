import 'package:flutter/material.dart';

/// Application-wide constants for the Vehicle Maintenance app

// ============================================================================
// VEHICLE TYPES
// ============================================================================

class VehicleTypes {
  static const String car = 'car';
  static const String truck = 'truck';
  static const String van = 'van';
  static const String motorcycle = 'motorcycle';
  static const String golfCart = 'golf_cart';
  static const String equipment = 'equipment';
  static const String other = 'other';

  static const List<String> all = [
    car,
    truck,
    van,
    motorcycle,
    golfCart,
    equipment,
    other,
  ];

  static String getLabel(String type) {
    switch (type) {
      case car:
        return 'Car';
      case truck:
        return 'Truck';
      case van:
        return 'Van';
      case motorcycle:
        return 'Motorcycle';
      case golfCart:
        return 'Golf Cart';
      case equipment:
        return 'Equipment';
      case other:
        return 'Other';
      default:
        return type;
    }
  }

  static IconData getIcon(String type) {
    switch (type) {
      case car:
        return Icons.directions_car;
      case truck:
        return Icons.local_shipping;
      case van:
        return Icons.airport_shuttle;
      case motorcycle:
        return Icons.two_wheeler;
      case golfCart:
        return Icons.golf_course;
      case equipment:
        return Icons.construction;
      case other:
      default:
        return Icons.help_outline;
    }
  }

  static List<DropdownMenuItem<String>> getDropdownItems() {
    return all.map((type) {
      return DropdownMenuItem(
        value: type,
        child: Text(getLabel(type)),
      );
    }).toList();
  }
}

// ============================================================================
// SERVICE & REMINDER CATEGORIES
// ============================================================================

class MaintenanceCategories {
  static const String oilChange = 'Oil change';
  static const String tireRotation = 'Tire rotation';
  static const String chargeRotation = 'Charge rotation';
  static const String brakeService = 'Brake service';
  static const String inspection = 'Inspection';
  static const String carWashDetail = 'Car wash / Detail';
  static const String other = 'Other';

  static const List<String> all = [
    oilChange,
    tireRotation,
    chargeRotation,
    brakeService,
    inspection,
    carWashDetail,
    other,
  ];

  static List<DropdownMenuItem<String>> getDropdownItems() {
    return all.map((category) {
      return DropdownMenuItem(
        value: category,
        child: Text(category),
      );
    }).toList();
  }
}

// ============================================================================
// DEVICE TYPES
// ============================================================================

class DeviceTypes {
  static const String obd = 'obd';
  static const String batteryMonitor = 'battery_monitor';
  static const String tracker = 'tracker';
  static const String other = 'other';

  static const List<String> all = [
    obd,
    batteryMonitor,
    tracker,
    other,
  ];

  static String getLabel(String type) {
    switch (type) {
      case obd:
        return 'OBD / telematics';
      case batteryMonitor:
        return 'Battery monitor';
      case tracker:
        return 'GPS tracker';
      case other:
        return 'Other';
      default:
        return type;
    }
  }

  static List<DropdownMenuItem<String>> getDropdownItems() {
    return all.map((type) {
      return DropdownMenuItem(
        value: type,
        child: Text(getLabel(type)),
      );
    }).toList();
  }
}

// ============================================================================
// ODOMETER UNITS
// ============================================================================

class OdometerUnits {
  static const String miles = 'mi';
  static const String kilometers = 'km';

  static const List<String> all = [miles, kilometers];

  static String getLabel(String unit) {
    switch (unit) {
      case miles:
        return 'Miles';
      case kilometers:
        return 'Kilometers';
      default:
        return unit;
    }
  }

  static List<DropdownMenuItem<String>> getDropdownItems() {
    return all.map((unit) {
      return DropdownMenuItem(
        value: unit,
        child: Text(getLabel(unit)),
      );
    }).toList();
  }
}

// ============================================================================
// REMINDER STATUS
// ============================================================================

class ReminderStatus {
  static const String overdue = 'overdue';
  static const String dueSoon = 'due_soon';
  static const String upcoming = 'upcoming';

  static Color getColor(String status) {
    switch (status) {
      case overdue:
        return Colors.red.shade100;
      case dueSoon:
        return Colors.orange.shade100;
      case upcoming:
        return Colors.blue.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  static Color getTextColor(String status) {
    switch (status) {
      case overdue:
        return Colors.red.shade900;
      case dueSoon:
        return Colors.orange.shade900;
      case upcoming:
        return Colors.blue.shade900;
      default:
        return Colors.grey.shade900;
    }
  }

  static String getLabel(String status) {
    switch (status) {
      case overdue:
        return 'OVERDUE';
      case dueSoon:
        return 'DUE SOON';
      case upcoming:
        return 'Upcoming';
      default:
        return status.toUpperCase();
    }
  }
}

// ============================================================================
// THRESHOLDS & LIMITS
// ============================================================================

class AppThresholds {
  // Reminder is considered "due soon" if within this many miles
  static const int dueSoonMileageThreshold = 200;

  // Device telemetry is considered "stale" after this many hours
  static const int staleDeviceHours = 24;
}

// ============================================================================
// DATABASE TABLE NAMES
// ============================================================================

class DbTables {
  static const String vehicles = 'vehicles';
  static const String reminders = 'reminders';
  static const String serviceEvents = 'service_events';
  static const String deviceLinks = 'device_links';
  static const String telemetryEvents = 'telemetry_events';
}

// ============================================================================
// UI CONSTANTS
// ============================================================================

class UiConstants {
  // Standard spacing
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 16.0;
  static const double spacingLarge = 24.0;

  // Border radius
  static const double borderRadiusSmall = 8.0;
  static const double borderRadiusMedium = 12.0;
  static const double borderRadiusLarge = 16.0;

  // Card elevation
  static const double cardElevation = 2.0;
}
