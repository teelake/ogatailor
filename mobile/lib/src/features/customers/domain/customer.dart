class Customer {
  const Customer({
    required this.id,
    required this.fullName,
    required this.gender,
    this.phoneNumber,
    this.notes,
    this.lastModifiedAt,
  });

  final String id;
  final String fullName;
  final String gender;
  final String? phoneNumber;
  final String? notes;
  final DateTime? lastModifiedAt;

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String,
      fullName: (json['full_name'] ?? '') as String,
      gender: (json['gender'] ?? 'other') as String,
      phoneNumber: json['phone_number'] as String?,
      notes: json['notes'] as String?,
      lastModifiedAt: DateTime.tryParse((json['last_modified_at'] ?? '').toString()),
    );
  }
}
