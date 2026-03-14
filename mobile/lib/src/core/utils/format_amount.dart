import 'package:intl/intl.dart';

/// Formats a numeric amount with comma separators (e.g. 1,234,567.89).
String formatAmount(num value, {int decimalDigits = 2}) {
  final pattern = decimalDigits > 0 ? '#,##0.${'0' * decimalDigits}' : '#,##0';
  return NumberFormat(pattern, 'en_US').format(value);
}
