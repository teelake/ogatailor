import 'dart:async';

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../../../core/sync/offline_sync_service.dart';
import '../domain/customer.dart';
import '../domain/measurement_entry.dart';

class CustomersRepository {
  CustomersRepository(this._dio, this._offlineSync);

  final Dio _dio;
  final OfflineSyncService _offlineSync;

  Future<List<Customer>> listCustomers() async {
    try {
      final response = await _dio.get('/api/customers');
      final data = Map<String, dynamic>.from(response.data as Map);
      final rows = List<Map<String, dynamic>>.from(data['data'] as List<dynamic>);
      await _offlineSync.saveCache('cache_customers', rows);
      return rows.map(Customer.fromJson).toList();
    } catch (_) {
      final rows = await _offlineSync.readCache('cache_customers');
      return rows.map(Customer.fromJson).toList();
    }
  }

  Future<void> createCustomer({
    required String fullName,
    String? phoneNumber,
    String? notes,
  }) async {
    final body = {
      'full_name': fullName,
      'phone_number': phoneNumber,
      'notes': notes,
    };
    try {
      await _dio.post('/api/customers', data: body);
      await _offlineSync.processQueue();
    } catch (_) {
      await _offlineSync.enqueue(method: 'POST', path: '/api/customers', data: body);
    }
  }

  Future<void> updateCustomer({
    required String customerId,
    required String fullName,
    String? phoneNumber,
    String? notes,
  }) async {
    final body = {
      'customer_id': customerId,
      'full_name': fullName,
      'phone_number': phoneNumber,
      'notes': notes,
    };
    try {
      await _dio.patch('/api/customers', data: body);
      await _offlineSync.processQueue();
    } catch (_) {
      await _offlineSync.enqueue(method: 'PATCH', path: '/api/customers', data: body);
    }
  }

  Future<void> archiveCustomer({
    required String customerId,
    required bool archived,
  }) async {
    final body = {
      'customer_id': customerId,
      'archived': archived,
    };
    try {
      await _dio.post('/api/customers/archive', data: body);
      await _offlineSync.processQueue();
    } catch (_) {
      await _offlineSync.enqueue(method: 'POST', path: '/api/customers/archive', data: body);
    }
  }

  Future<void> deleteCustomer({
    required String customerId,
  }) async {
    final body = {'customer_id': customerId};
    try {
      await _dio.delete('/api/customers', data: body);
      await _offlineSync.processQueue();
    } catch (_) {
      await _offlineSync.enqueue(method: 'DELETE', path: '/api/customers', data: body);
    }
  }

  Future<List<MeasurementEntry>> listMeasurements({required String customerId}) async {
    try {
      final response = await _dio.get(
        '/api/measurements',
        queryParameters: {'customer_id': customerId},
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      final rows = List<Map<String, dynamic>>.from(data['data'] as List<dynamic>);
      await _offlineSync.saveCache('cache_measurements_$customerId', rows);
      return rows.map(MeasurementEntry.fromJson).toList();
    } catch (_) {
      final rows = await _offlineSync.readCache('cache_measurements_$customerId');
      return rows.map(MeasurementEntry.fromJson).toList();
    }
  }

  Future<void> createMeasurement({
    required String customerId,
    required DateTime takenAt,
    required Map<String, dynamic> payload,
  }) async {
    final body = {
      'customer_id': customerId,
      'taken_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(takenAt),
      'payload': payload,
    };
    try {
      await _dio.post('/api/measurements', data: body);
      await _offlineSync.processQueue();
    } catch (_) {
      await _offlineSync.enqueue(method: 'POST', path: '/api/measurements', data: body);
    }
  }

  Future<void> updateMeasurement({
    required String measurementId,
    required DateTime takenAt,
    required Map<String, dynamic> payload,
  }) async {
    final body = {
      'measurement_id': measurementId,
      'taken_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(takenAt),
      'payload': payload,
    };
    try {
      await _dio.patch('/api/measurements', data: body);
      await _offlineSync.processQueue();
    } catch (_) {
      await _offlineSync.enqueue(method: 'PATCH', path: '/api/measurements', data: body);
    }
  }
}
