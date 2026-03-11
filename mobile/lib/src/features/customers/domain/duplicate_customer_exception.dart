/// Thrown when creating/updating a customer with a name that already exists.
/// Use [existingCustomerId] to navigate to the existing customer or
/// retry with [forceDuplicate: true] to add anyway.
class DuplicateCustomerException implements Exception {
  DuplicateCustomerException({
    required this.existingCustomerId,
    required this.customerName,
    this.message,
  });

  final String existingCustomerId;
  final String customerName;
  final String? message;

  @override
  String toString() => message ?? 'A customer named "$customerName" already exists.';
}
