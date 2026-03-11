class OrderEntry {
  const OrderEntry({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.title,
    required this.status,
    required this.amountTotal,
    this.dueDate,
    this.notes,
    this.lastModifiedAt,
  });

  final String id;
  final String customerId;
  final String customerName;
  final String title;
  final String status;
  final double amountTotal;
  final DateTime? dueDate;
  final String? notes;
  final DateTime? lastModifiedAt;

  factory OrderEntry.fromJson(Map<String, dynamic> json) {
    return OrderEntry(
      id: json['id'] as String,
      customerId: json['customer_id'] as String,
      customerName: (json['customer_name'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      status: (json['status'] ?? 'pending') as String,
      amountTotal: double.tryParse((json['amount_total'] ?? '0').toString()) ?? 0,
      dueDate: DateTime.tryParse((json['due_date'] ?? '').toString()),
      notes: json['notes'] as String?,
      lastModifiedAt: DateTime.tryParse((json['last_modified_at'] ?? '').toString()),
    );
  }
}
