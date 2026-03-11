class MeasurementEntry {
  const MeasurementEntry({
    required this.id,
    required this.customerId,
    required this.takenAt,
    required this.payload,
    this.lastModifiedAt,
  });

  final String id;
  final String customerId;
  final DateTime takenAt;
  final Map<String, dynamic> payload;
  final DateTime? lastModifiedAt;

  factory MeasurementEntry.fromJson(Map<String, dynamic> json) {
    return MeasurementEntry(
      id: json['id'] as String,
      customerId: json['customer_id'] as String,
      takenAt: DateTime.tryParse((json['taken_at'] ?? '').toString()) ?? DateTime.now(),
      payload: Map<String, dynamic>.from((json['payload'] ?? <String, dynamic>{}) as Map),
      lastModifiedAt: DateTime.tryParse((json['last_modified_at'] ?? '').toString()),
    );
  }
}
