class Customer {
  const Customer({
    required this.id,
    required this.fullName,
    this.phoneNumber,
  });

  final String id;
  final String fullName;
  final String? phoneNumber;

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String,
      fullName: (json['full_name'] ?? '') as String,
      phoneNumber: json['phone_number'] as String?,
    );
  }
}
