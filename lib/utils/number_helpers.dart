import 'package:intl/intl.dart';

/// Number formatting helpers for the application

class NumberHelpers {
  /// Formats a number with thousand separators
  /// Example: 125000 -> "125,000"
  static String formatNumber(num? value) {
    if (value == null) return '0';
    final formatter = NumberFormat('#,###');
    return formatter.format(value);
  }

  /// Formats an odometer reading with unit
  /// Example: (125000, 'mi') -> "125,000 mi"
  static String formatOdometer(num? value, String? unit) {
    if (value == null) return 'N/A';
    final formatted = formatNumber(value);
    final unitStr = unit ?? 'mi';
    return '$formatted $unitStr';
  }

  /// Formats currency value
  /// Example: 45.99 -> "$45.99"
  static String formatCurrency(num? value) {
    if (value == null) return '\$0.00';
    final formatter = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    return formatter.format(value);
  }

  /// Parses a string to a number, returns null if invalid
  static num? parseNumber(String? input) {
    if (input == null || input.isEmpty) return null;

    // Remove commas and whitespace
    final cleaned = input.replaceAll(RegExp(r'[,\s]'), '');

    return num.tryParse(cleaned);
  }

  /// Parses a string to an integer, returns null if invalid
  static int? parseInt(String? input) {
    if (input == null || input.isEmpty) return null;

    // Remove commas and whitespace
    final cleaned = input.replaceAll(RegExp(r'[,\s]'), '');

    return int.tryParse(cleaned);
  }

  /// Parses a string to a double, returns null if invalid
  static double? parseDouble(String? input) {
    if (input == null || input.isEmpty) return null;

    // Remove commas and whitespace
    final cleaned = input.replaceAll(RegExp(r'[,\s]'), '');

    return double.tryParse(cleaned);
  }

  /// Validates if a string is a valid number
  static bool isValidNumber(String? input) {
    return parseNumber(input) != null;
  }

  /// Validates if a string is a valid positive number
  static bool isValidPositiveNumber(String? input) {
    final number = parseNumber(input);
    return number != null && number > 0;
  }
}
