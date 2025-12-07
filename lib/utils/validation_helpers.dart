/// Input validation helpers for forms and user input
library;

class ValidationHelpers {
  /// Validates email format
  static bool isValidEmail(String? email) {
    if (email == null || email.isEmpty) return false;

    // Basic email regex pattern
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    return emailRegex.hasMatch(email);
  }

  /// Gets email validation error message
  static String? validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return 'Email is required';
    }

    if (!isValidEmail(email)) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  /// Validates password meets minimum requirements
  static bool isValidPassword(String? password, {int minLength = 6}) {
    if (password == null || password.isEmpty) return false;
    return password.length >= minLength;
  }

  /// Gets password validation error message
  static String? validatePassword(String? password, {int minLength = 6}) {
    if (password == null || password.isEmpty) {
      return 'Password is required';
    }

    if (password.length < minLength) {
      return 'Password must be at least $minLength characters';
    }

    return null;
  }

  /// Validates required text field
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validates a number is within a range
  static String? validateNumberRange(
    String? value,
    String fieldName, {
    num? min,
    num? max,
  }) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }

    final number = num.tryParse(value);
    if (number == null) {
      return '$fieldName must be a valid number';
    }

    if (min != null && number < min) {
      return '$fieldName must be at least $min';
    }

    if (max != null && number > max) {
      return '$fieldName must be at most $max';
    }

    return null;
  }

  /// Validates a year is reasonable for a vehicle
  static String? validateVehicleYear(String? value) {
    final currentYear = DateTime.now().year;
    return validateNumberRange(
      value,
      'Year',
      min: 1900,
      max: currentYear + 2, // Allow next year models
    );
  }

  /// Validates odometer reading
  static String? validateOdometer(String? value) {
    return validateNumberRange(
      value,
      'Odometer',
      min: 0,
      max: 999999999, // ~1 billion
    );
  }

  /// Validates cost/price
  static String? validateCost(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Cost is optional
    }

    final number = num.tryParse(value);
    if (number == null) {
      return 'Cost must be a valid number';
    }

    if (number < 0) {
      return 'Cost cannot be negative';
    }

    return null;
  }

  /// Validates text length
  static String? validateLength(
    String? value,
    String fieldName, {
    int? minLength,
    int? maxLength,
  }) {
    if (value == null || value.isEmpty) {
      return null; // Allow empty if optional
    }

    if (minLength != null && value.length < minLength) {
      return '$fieldName must be at least $minLength characters';
    }

    if (maxLength != null && value.length > maxLength) {
      return '$fieldName must be at most $maxLength characters';
    }

    return null;
  }

  /// Validates phone number format (basic US format)
  static bool isValidPhoneNumber(String? phone) {
    if (phone == null || phone.isEmpty) return false;

    // Remove all non-digit characters
    final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');

    // Check if it's 10 or 11 digits (with or without country code)
    return digitsOnly.length == 10 || digitsOnly.length == 11;
  }

  /// Gets phone number validation error message
  static String? validatePhoneNumber(String? phone) {
    if (phone == null || phone.isEmpty) {
      return null; // Phone is optional
    }

    if (!isValidPhoneNumber(phone)) {
      return 'Please enter a valid phone number';
    }

    return null;
  }

  /// Validates URL format
  static bool isValidUrl(String? url) {
    if (url == null || url.isEmpty) return false;

    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && uri.hasAuthority;
    } catch (_) {
      return false;
    }
  }

  /// Gets URL validation error message
  static String? validateUrl(String? url) {
    if (url == null || url.isEmpty) {
      return null; // URL is optional
    }

    if (!isValidUrl(url)) {
      return 'Please enter a valid URL';
    }

    return null;
  }
}
