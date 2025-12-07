# Quick Start Guide - New Architecture

This guide shows you how to use the newly implemented architecture in your pages.

---

## 🔐 Environment Setup

Your `.env` file contains the Supabase credentials. Make sure it exists:

```bash
# The .env file should contain:
SUPABASE_URL=https://liunnxxgomegfjljybrs.supabase.co
SUPABASE_ANON_KEY=your_anon_key_here
```

**Note**: Never commit the `.env` file. Use `.env.example` for documentation.

---

## 📦 Import the New Utilities

Add these imports at the top of your page files:

```dart
// Constants
import '../constants/app_constants.dart';

// Services
import '../services/vehicle_service.dart';
import '../services/reminder_service.dart';
import '../services/service_event_service.dart';
import '../services/device_service.dart';
import '../services/auth_service.dart';

// Helpers
import '../utils/date_helpers.dart';
import '../utils/reminder_helpers.dart';
import '../utils/number_helpers.dart';
import '../utils/validation_helpers.dart';
```

---

## 🚗 Using the Vehicle Service

### Fetch all vehicles
```dart
final vehicleService = VehicleService();
final vehicles = await vehicleService.getVehicles();
```

### Create a new vehicle
```dart
final vehicle = await vehicleService.createVehicle(
  name: 'My Truck',
  vehicleType: VehicleTypes.truck,
  year: '2020',
  make: 'Ford',
  model: 'F-150',
  currentOdometer: 50000,
  odometerUnit: OdometerUnits.miles,
);
```

### Update odometer
```dart
await vehicleService.updateOdometer(vehicleId, 50500);
```

### Delete a vehicle
```dart
await vehicleService.deleteVehicle(vehicleId);
```

---

## 🔔 Using the Reminder Service

### Fetch reminders for a vehicle
```dart
final reminderService = ReminderService();
final reminders = await reminderService.getRemindersForVehicle(vehicleId);
```

### Create a reminder
```dart
final reminder = await reminderService.createReminder(
  vehicleId: vehicleId,
  type: MaintenanceCategories.oilChange,
  nextDueDate: '2024-12-31',
  nextDueOdometer: 55000,
  intervalDays: 90,
  intervalMiles: 5000,
);
```

### Mark reminder as done (auto-advances)
```dart
await reminderService.markReminderDone(reminderId);
```

---

## 🔧 Using the Service Event Service

### Get service history
```dart
final serviceEventService = ServiceEventService();
final events = await serviceEventService.getServiceEventsForVehicle(vehicleId);
```

### Create a service event
```dart
final event = await serviceEventService.createServiceEvent(
  vehicleId: vehicleId,
  serviceDate: DateTime.now().toIso8601String(),
  category: MaintenanceCategories.oilChange,
  odometer: 50000,
  cost: 45.99,
  performedBy: 'Joe\'s Auto Shop',
  notes: 'Full synthetic oil',
);
```

### Quick charge rotation (for golf carts)
```dart
await serviceEventService.createChargeRotationEvent(vehicleId: vehicleId);
```

---

## 📱 Using the Device Service

### Get devices for a vehicle
```dart
final deviceService = DeviceService();
final devices = await deviceService.getDeviceLinksForVehicle(vehicleId);
```

### Create a device link
```dart
final link = await deviceService.createDeviceLink(
  vehicleId: vehicleId,
  deviceId: 'ABC123',
  deviceType: DeviceTypes.obd,
  nickname: 'My OBD Reader',
);
```

### Get latest telemetry
```dart
final telemetry = await deviceService.getLatestTelemetry(deviceId);
```

### Check if device is stale
```dart
final isStale = await deviceService.isDeviceStale(deviceId);
```

---

## 📅 Using Date Helpers

### Format dates
```dart
// ISO string to MM/DD/YYYY
final formatted = DateHelpers.formatDate('2024-12-07'); // "12/7/2024"

// DateTime object
final formatted = DateHelpers.formatDateTime(DateTime.now());

// Custom format
final formatted = DateHelpers.formatDateCustom(isoString, 'MMM dd, yyyy');
```

### Date checks
```dart
if (DateHelpers.isToday(someDate)) {
  // It's today!
}

if (DateHelpers.isPast(dueDate)) {
  // Overdue!
}

final days = DateHelpers.daysBetween(startDate, endDate);
```

---

## 🔔 Using Reminder Helpers

### Calculate reminder status
```dart
final status = ReminderHelpers.calculateStatus(reminder, vehicle);
// Returns: 'overdue', 'due_soon', or 'upcoming'
```

### Get status colors
```dart
final bgColor = ReminderHelpers.getStatusColor(status);
final textColor = ReminderHelpers.getStatusTextColor(status);
```

### Calculate remaining mileage
```dart
final remaining = ReminderHelpers.calculateRemainingMileage(reminder, vehicle);
// Returns: num? (miles/km remaining)
```

### Group reminders
```dart
final grouped = ReminderHelpers.groupByStatus(reminders, vehiclesMap);
// Returns: Map<String, List<Map>>
// Keys: 'overdue', 'due_soon', 'upcoming'
```

---

## 🔢 Using Number Helpers

### Format numbers
```dart
NumberHelpers.formatNumber(125000)           // "125,000"
NumberHelpers.formatOdometer(125000, 'mi')   // "125,000 mi"
NumberHelpers.formatCurrency(45.99)          // "$45.99"
```

### Parse numbers (handles commas)
```dart
final value = NumberHelpers.parseNumber("125,000"); // 125000
final cost = NumberHelpers.parseDouble("45.99");    // 45.99
```

---

## ✅ Using Validation Helpers

### Add validation to forms
```dart
TextFormField(
  controller: emailController,
  validator: ValidationHelpers.validateEmail,
  autovalidateMode: AutovalidateMode.onUserInteraction,
)

TextFormField(
  controller: yearController,
  validator: ValidationHelpers.validateVehicleYear,
)

TextFormField(
  controller: odometerController,
  validator: ValidationHelpers.validateOdometer,
)
```

### Manual validation
```dart
final emailError = ValidationHelpers.validateEmail(email);
if (emailError != null) {
  // Show error
}
```

---

## 🎨 Using Constants

### Vehicle types
```dart
// Use constant values
final type = VehicleTypes.car;

// Get label
final label = VehicleTypes.getLabel(type); // "Car"

// Get icon
final icon = VehicleTypes.getIcon(type); // Icons.directions_car

// Get dropdown items
DropdownButton<String>(
  items: VehicleTypes.getDropdownItems(),
  // ...
)
```

### Maintenance categories
```dart
// Use constant values
final category = MaintenanceCategories.oilChange;

// Get dropdown items
DropdownButton<String>(
  items: MaintenanceCategories.getDropdownItems(),
  // ...
)
```

### Device types
```dart
final deviceType = DeviceTypes.obd;
final label = DeviceTypes.getLabel(deviceType); // "OBD / telematics"
```

### Thresholds
```dart
// Check if due soon
if (remaining <= AppThresholds.dueSoonMileageThreshold) {
  // Within 200 miles!
}

// Check if device is stale
final hoursSince = now.difference(lastUpdate).inHours;
if (hoursSince > AppThresholds.staleDeviceHours) {
  // Device hasn't reported in 24+ hours
}
```

### Database tables
```dart
await supabase.from(DbTables.vehicles).select();
await supabase.from(DbTables.reminders).select();
```

---

## 🏗️ Complete Example: Refactored Page Method

### Before (Old Pattern)
```dart
Future<void> _loadVehicles() async {
  setState(() {
    _loading = true;
  });

  try {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) {
      throw Exception('Not authenticated');
    }

    final response = await supabase
        .from('vehicles')
        .select()
        .eq('user_id', userId)
        .order('created_at');

    setState(() {
      _vehicles = List<Map<String, dynamic>>.from(response);
      _loading = false;
    });
  } catch (e) {
    setState(() {
      _error = e.toString();
      _loading = false;
    });
  }
}
```

### After (New Pattern)
```dart
Future<void> _loadVehicles() async {
  setState(() {
    _loading = true;
  });

  try {
    final vehicleService = VehicleService();
    final vehicles = await vehicleService.getVehicles();

    setState(() {
      _vehicles = vehicles;
      _loading = false;
    });
  } catch (e) {
    setState(() {
      _error = e.toString();
      _loading = false;
    });
  }
}
```

**Benefits**:
- Much cleaner and more readable
- Service handles auth checks
- Service handles error handling
- Easy to test (can mock VehicleService)
- Easy to add caching later

---

## 💡 Tips

1. **Create service instances once** in initState if you'll use them multiple times
2. **Use constants everywhere** - avoid hardcoded strings
3. **Validate all forms** using ValidationHelpers
4. **Format all dates** using DateHelpers
5. **Format all numbers** using NumberHelpers
6. **Calculate reminder status** using ReminderHelpers

---

## 📚 More Information

- **Full API Reference**: See `IMPROVEMENTS.md`
- **Implementation Details**: See `IMPLEMENTATION_SUMMARY.md`
- **Migration Guide**: See the "Migration Guide" section in `IMPROVEMENTS.md`

---

Happy coding! 🚀
