import 'package:intl/intl.dart';

/// Safely parses a dynamic value to num (handles String from JSON/API).
num parseAmount(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value;
  if (value is String) return num.tryParse(value) ?? 0;
  return 0;
}

/// Formats a numeric amount with comma separators (e.g. 1,234,567.89).
String formatAmount(num value, {int decimalDigits = 2}) {
  final pattern = decimalDigits > 0 ? '#,##0.${'0' * decimalDigits}' : '#,##0';
  return NumberFormat(pattern, 'en_US').format(value);
}
