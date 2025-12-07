# Code Improvements Documentation

This document outlines the architectural improvements made to the Vehicle Maintenance Mobile app to enhance code quality, maintainability, and security.

---

## Summary of Changes

### 1. Security Improvements ✅
**Problem**: Supabase credentials were hardcoded in `lib/main.dart`, exposing them in source control.

**Solution**:
- Added `flutter_dotenv` package for environment variable management
- Moved credentials to `.env` file (gitignored)
- Created `.env.example` for documentation
- Updated `lib/main.dart` to load credentials from environment

**Files Modified**:
- `lib/main.dart` - Now loads credentials from `.env`
- `pubspec.yaml` - Added `flutter_dotenv` dependency
- `.env` - Contains actual credentials (gitignored)
- `.env.example` - Template for other developers

**Usage**:
```dart
// Credentials are now loaded from .env file
await dotenv.load(fileName: '.env');
final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
```

---

### 2. Constants Organization ✅
**Problem**: Hardcoded values (vehicle types, service categories, device types, magic numbers) scattered throughout the codebase.

**Solution**: Created a centralized constants file with organized classes.

**Files Created**:
- `lib/constants/app_constants.dart`

**Features**:
- `VehicleTypes` - Vehicle type constants with labels, icons, and dropdown helpers
- `MaintenanceCategories` - Service and reminder categories
- `DeviceTypes` - IoT device type constants
- `OdometerUnits` - Odometer unit constants (miles/km)
- `ReminderStatus` - Status constants with colors and labels
- `AppThresholds` - Configurable thresholds (due soon mileage, stale device hours)
- `DbTables` - Database table name constants
- `UiConstants` - UI spacing, border radius, and elevation constants

**Usage Example**:
```dart
// Before:
value: 'car'

// After:
value: VehicleTypes.car

// Get dropdown items:
DropdownButton(
  items: VehicleTypes.getDropdownItems(),
)

// Get icon:
Icon(VehicleTypes.getIcon(vehicle['vehicle_type']))

// Use thresholds:
if (remaining <= AppThresholds.dueSoonMileageThreshold) {
  // ...
}
```

---

### 3. Utility Functions ✅
**Problem**: Duplicate helper functions across multiple files (date formatting, status calculation, etc.)

**Solution**: Created dedicated utility files with reusable helper functions.

**Files Created**:
- `lib/utils/date_helpers.dart` - Date formatting and manipulation
- `lib/utils/reminder_helpers.dart` - Reminder status calculation
- `lib/utils/number_helpers.dart` - Number and currency formatting
- `lib/utils/validation_helpers.dart` - Input validation

#### DateHelpers
```dart
// Format ISO date string
DateHelpers.formatDate('2024-12-07') // "12/7/2024"

// Format DateTime object
DateHelpers.formatDateTime(DateTime.now()) // "12/7/2024"

// Custom format
DateHelpers.formatDateCustom(isoString, 'MMM dd, yyyy') // "Dec 07, 2024"

// Check if today
DateHelpers.isToday(someDate) // true/false

// Check if past
DateHelpers.isPast(someDate) // true/false
```

#### ReminderHelpers
```dart
// Calculate reminder status
final status = ReminderHelpers.calculateStatus(reminder, vehicle);

// Get status color
final color = ReminderHelpers.getStatusColor(status);

// Calculate remaining mileage
final remaining = ReminderHelpers.calculateRemainingMileage(reminder, vehicle);

// Group reminders by status
final grouped = ReminderHelpers.groupByStatus(reminders, vehiclesMap);
```

#### NumberHelpers
```dart
// Format with thousands separator
NumberHelpers.formatNumber(125000) // "125,000"

// Format odometer
NumberHelpers.formatOdometer(125000, 'mi') // "125,000 mi"

// Format currency
NumberHelpers.formatCurrency(45.99) // "$45.99"

// Parse numbers (handles commas)
NumberHelpers.parseNumber("125,000") // 125000
```

#### ValidationHelpers
```dart
// Email validation
ValidationHelpers.validateEmail(email) // null or error message

// Password validation
ValidationHelpers.validatePassword(password, minLength: 8)

// Required field
ValidationHelpers.validateRequired(value, 'Vehicle name')

// Number range
ValidationHelpers.validateNumberRange(value, 'Year', min: 1900, max: 2025)

// Vehicle year
ValidationHelpers.validateVehicleYear(yearStr)

// Odometer
ValidationHelpers.validateOdometer(odometerStr)

// Cost
ValidationHelpers.validateCost(costStr)
```

---

### 4. Service Layer Architecture ✅
**Problem**: Database queries scattered throughout UI pages, making code difficult to test and maintain.

**Solution**: Created a complete service layer to abstract data access from UI.

**Files Created**:
- `lib/services/base_service.dart` - Base class with common functionality
- `lib/services/auth_service.dart` - Authentication operations
- `lib/services/vehicle_service.dart` - Vehicle CRUD operations
- `lib/services/reminder_service.dart` - Reminder management
- `lib/services/service_event_service.dart` - Service history management
- `lib/services/device_service.dart` - IoT device and telemetry management

#### BaseService
Provides common functionality:
- Access to Supabase client
- User authentication checks
- Error handling wrappers

#### AuthService
```dart
final authService = AuthService();

// Sign in
await authService.signIn(email: email, password: password);

// Sign up
await authService.signUp(email: email, password: password);

// Sign out
await authService.signOut();

// Check if authenticated
if (authService.isAuthenticated) { ... }

// Listen to auth state
authService.authStateChanges.listen((state) { ... });
```

#### VehicleService
```dart
final vehicleService = VehicleService();

// Get all vehicles
final vehicles = await vehicleService.getVehicles();

// Get single vehicle
final vehicle = await vehicleService.getVehicle(vehicleId);

// Create vehicle
final newVehicle = await vehicleService.createVehicle(
  name: 'My Car',
  vehicleType: VehicleTypes.car,
  currentOdometer: 50000,
  odometerUnit: OdometerUnits.miles,
);

// Update vehicle
await vehicleService.updateVehicle(vehicleId, {
  'name': 'Updated Name',
});

// Update odometer
await vehicleService.updateOdometer(vehicleId, 50500);

// Delete vehicle (cascades to related data)
await vehicleService.deleteVehicle(vehicleId);

// Get vehicle count
final count = await vehicleService.getVehicleCount();
```

#### ReminderService
```dart
final reminderService = ReminderService();

// Get all reminders
final reminders = await reminderService.getReminders();

// Get reminders for vehicle
final vehicleReminders = await reminderService.getRemindersForVehicle(vehicleId);

// Create reminder
final reminder = await reminderService.createReminder(
  vehicleId: vehicleId,
  type: MaintenanceCategories.oilChange,
  nextDueDate: '2024-12-31',
  nextDueOdometer: 55000,
  intervalDays: 90,
  intervalMiles: 5000,
);

// Mark reminder as done (advances by interval)
await reminderService.markReminderDone(reminderId);

// Update reminder
await reminderService.updateReminder(reminderId, updates);

// Delete reminder
await reminderService.deleteReminder(reminderId);

// Toggle active status
await reminderService.toggleReminderActive(reminderId);
```

#### ServiceEventService
```dart
final serviceEventService = ServiceEventService();

// Get service events for vehicle
final events = await serviceEventService.getServiceEventsForVehicle(vehicleId);

// Create service event
final event = await serviceEventService.createServiceEvent(
  vehicleId: vehicleId,
  serviceDate: DateTime.now().toIso8601String(),
  category: MaintenanceCategories.oilChange,
  odometer: 50000,
  cost: 45.99,
  performedBy: 'Joe\'s Auto Shop',
  notes: 'Full synthetic oil',
);

// Get most recent service
final recent = await serviceEventService.getMostRecentServiceEvent(vehicleId);

// Get events by category
final oilChanges = await serviceEventService.getServiceEventsByCategory(
  vehicleId,
  MaintenanceCategories.oilChange,
);

// Get total service cost
final total = await serviceEventService.getTotalServiceCost(vehicleId);

// Quick charge rotation (for golf carts)
await serviceEventService.createChargeRotationEvent(vehicleId: vehicleId);
```

#### DeviceService
```dart
final deviceService = DeviceService();

// Get device links for vehicle
final devices = await deviceService.getDeviceLinksForVehicle(vehicleId);

// Create device link
final link = await deviceService.createDeviceLink(
  vehicleId: vehicleId,
  deviceId: 'ABC123',
  deviceType: DeviceTypes.obd,
  nickname: 'My OBD Reader',
);

// Get latest telemetry
final telemetry = await deviceService.getLatestTelemetry(deviceId);

// Check if device is stale
final isStale = await deviceService.isDeviceStale(deviceId);

// Get stale device count
final staleCount = await deviceService.getStaleDeviceCount();

// Create telemetry event
await deviceService.createTelemetryEvent(
  vehicleId: vehicleId,
  deviceId: deviceId,
  recordedAt: DateTime.now().toIso8601String(),
  odometer: 50123,
  batterySoc: 85,
  batteryVoltage: 12.6,
);
```

---

## Migration Guide

### How to Use the New Architecture in Your Pages

#### Before (Old Pattern):
```dart
// Direct Supabase calls in the UI
final supabase = Supabase.instance.client;
final response = await supabase
    .from('vehicles')
    .select()
    .eq('user_id', supabase.auth.currentUser?.id)
    .order('created_at');
final vehicles = List<Map<String, dynamic>>.from(response);
```

#### After (New Pattern):
```dart
// Use the service layer
final vehicleService = VehicleService();
final vehicles = await vehicleService.getVehicles();
```

### Replacing Hardcoded Values

#### Before:
```dart
DropdownMenuItem(value: 'car', child: Text('Car'))
DropdownMenuItem(value: 'truck', child: Text('Truck'))
// ... more items
```

#### After:
```dart
DropdownButton(
  items: VehicleTypes.getDropdownItems(),
  // ...
)
```

### Using Helper Functions

#### Before:
```dart
String _formatDate(String? isoString) {
  if (isoString == null) return 'No date';
  try {
    final d = DateTime.parse(isoString);
    return '${d.month}/${d.day}/${d.year}';
  } catch (_) {
    return 'Invalid date';
  }
}
```

#### After:
```dart
import '../utils/date_helpers.dart';

// Just use the helper
final formatted = DateHelpers.formatDate(isoString);
```

### Adding Form Validation

#### Before:
```dart
TextField(
  controller: emailController,
  // No validation
)
```

#### After:
```dart
TextFormField(
  controller: emailController,
  validator: ValidationHelpers.validateEmail,
  autovalidateMode: AutovalidateMode.onUserInteraction,
)
```

---

## Benefits of These Changes

### 1. Security
- Credentials no longer exposed in source code
- Safe to commit code to public repositories
- Easy to rotate credentials without code changes

### 2. Maintainability
- Single source of truth for constants
- Easy to update values across entire app
- Reduced code duplication
- Clear separation of concerns

### 3. Testability
- Service layer can be easily mocked for unit tests
- Business logic separated from UI
- Helper functions are pure and testable

### 4. Developer Experience
- Autocomplete for constants
- Type-safe access to database tables
- Consistent formatting across the app
- Clear API for data operations

### 5. Scalability
- Easy to add new vehicle types or categories
- Service layer can be extended with caching
- Can add middleware for logging/analytics
- Ready for state management integration

---

## Next Steps

The following improvements are recommended as follow-up work:

### High Priority
1. **Refactor pages to use services** - Update all pages to use the new service layer
2. **Add state management** - Implement Provider/Riverpod for better state handling
3. **Add unit tests** - Write tests for services and helpers
4. **Add form validation** - Update all forms to use ValidationHelpers

### Medium Priority
5. **Break up large pages** - Split monolithic pages into smaller widgets
6. **Add navigation management** - Implement proper routing
7. **Improve error handling** - Add user-friendly error messages
8. **Add loading states** - Use skeleton loaders

### Nice to Have
9. **Add offline support** - Implement local database with sync
10. **Add push notifications** - Notify users of overdue reminders
11. **Add export functionality** - Allow exporting service history
12. **Add analytics** - Track user behavior

---

## File Structure

```
lib/
├── constants/
│   └── app_constants.dart         # All app-wide constants
├── services/
│   ├── base_service.dart          # Base service class
│   ├── auth_service.dart          # Authentication
│   ├── vehicle_service.dart       # Vehicle operations
│   ├── reminder_service.dart      # Reminder operations
│   ├── service_event_service.dart # Service history
│   └── device_service.dart        # IoT devices & telemetry
├── utils/
│   ├── date_helpers.dart          # Date formatting
│   ├── reminder_helpers.dart      # Reminder status logic
│   ├── number_helpers.dart        # Number formatting
│   └── validation_helpers.dart    # Input validation
├── pages/
│   └── [existing pages]           # UI pages (to be refactored)
└── main.dart                      # App entry (updated for .env)
```

---

## Questions?

If you have questions about using these new utilities or services, refer to:
- Code comments in each file
- Usage examples in this document
- Existing implementations (once pages are migrated)
