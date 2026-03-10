import 'dart:async';

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../domain/customer.dart';
import '../domain/measurement_entry.dart';

class CustomersRepository {
  CustomersRepository(this._dio);

  final Dio _dio;

  Future<List<Customer>> listCustomers({required String ownerUserId}) async {
    final response = await _dio.get(
      '/api/customers',
      queryParameters: {'owner_user_id': ownerUserId},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final rows = List<Map<String, dynamic>>.from(data['data'] as List<dynamic>);
    return rows.map(Customer.fromJson).toList();
  }

  Future<void> createCustomer({
    required String ownerUserId,
    required String fullName,
    String? phoneNumber,
    String? notes,
  }) async {
    await _dio.post(
      '/api/customers',
      data: {
        'owner_user_id': ownerUserId,
        'full_name': fullName,
        'phone_number': phoneNumber,
        'notes': notes,
      },
    );
  }

  Future<void> updateCustomer({
    required String customerId,
    required String ownerUserId,
    required String fullName,
    String? phoneNumber,
    String? notes,
  }) async {
    await _dio.patch(
      '/api/customers',
      data: {
        'customer_id': customerId,
        'owner_user_id': ownerUserId,
        'full_name': fullName,
        'phone_number': phoneNumber,
        'notes': notes,
      },
    );
  }

  Future<void> archiveCustomer({
    required String customerId,
    required String ownerUserId,
    required bool archived,
  }) async {
    await _dio.post(
      '/api/customers/archive',
      data: {
        'customer_id': customerId,
        'owner_user_id': ownerUserId,
        'archived': archived,
      },
    );
  }

  Future<void> deleteCustomer({
    required String customerId,
    required String ownerUserId,
  }) async {
    await _dio.delete(
      '/api/customers',
      data: {
        'customer_id': customerId,
        'owner_user_id': ownerUserId,
      },
    );
  }

  Future<List<MeasurementEntry>> listMeasurements({required String customerId}) async {
    final response = await _dio.get(
      '/api/measurements',
      queryParameters: {'customer_id': customerId},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final rows = List<Map<String, dynamic>>.from(data['data'] as List<dynamic>);
    return rows.map(MeasurementEntry.fromJson).toList();
  }

  Future<void> createMeasurement({
    required String customerId,
    required DateTime takenAt,
    required Map<String, dynamic> payload,
  }) async {
    await _dio.post(
      '/api/measurements',
      data: {
        'customer_id': customerId,
        'taken_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(takenAt),
        'payload': payload,
      },
    );
  }

  Future<void> updateMeasurement({
    required String measurementId,
    required DateTime takenAt,
    required Map<String, dynamic> payload,
  }) async {
    await _dio.patch(
      '/api/measurements',
      data: {
        'measurement_id': measurementId,
        'taken_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(takenAt),
        'payload': payload,
      },
    );
  }
}
