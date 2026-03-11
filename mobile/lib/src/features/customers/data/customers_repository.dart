import 'dart:async';

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../../../core/sync/offline_sync_service.dart';
import '../domain/customer.dart';
import '../domain/duplicate_customer_exception.dart';
import '../domain/measurement_entry.dart';

class CustomersRepository {
  CustomersRepository(this._dio, this._offlineSync);

  final Dio _dio;
  final OfflineSyncService _offlineSync;

  Future<List<Customer>> listCustomers() async {
    final all = <Customer>[];
    var offset = 0;
    const limit = 200;
    while (true) {
      final page = await listCustomersPage(limit: limit, offset: offset);
      all.addAll(page.items);
      if (!page.hasMore || page.items.isEmpty) break;
      offset += page.items.length;
    }
    return all;
  }

  Future<CustomersPage> listCustomersPage({
    required int limit,
    required int offset,
    String? query,
  }) async {
    try {
      final response = await _dio.get(
        '/api/customers',
        queryParameters: {
          'limit': limit,
          'offset': offset,
          if ((query ?? '').trim().isNotEmpty) 'q': query!.trim(),
        },
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      final rows = List<Map<String, dynamic>>.from(data['data'] as List<dynamic>);
      if (offset == 0 && (query == null || query.trim().isEmpty)) {
        await _offlineSync.saveCache('cache_customers', rows);
      }
      final meta = Map<String, dynamic>.from((data['meta'] ?? const <String, dynamic>{}) as Map);
      return CustomersPage(
        items: rows.map(Customer.fromJson).toList(),
        total: (meta['total'] ?? rows.length) as int,
        hasMore: (meta['has_more'] ?? false) as bool,
      );
    } catch (_) {
      final rows = await _offlineSync.readCache('cache_customers');
      final q = (query ?? '').trim().toLowerCase();
      final filtered = q.isEmpty
          ? rows
          : rows
              .where(
                (r) =>
                    ((r['full_name'] ?? '').toString().toLowerCase().contains(q)) ||
                    ((r['phone_number'] ?? '').toString().toLowerCase().contains(q)),
              )
              .toList();
      final safeOffset = offset.clamp(0, filtered.length) as int;
      final end = (safeOffset + limit).clamp(0, filtered.length) as int;
      final slice = filtered.sublist(safeOffset, end);
      return CustomersPage(
        items: slice.map(Customer.fromJson).toList(),
        total: filtered.length,
        hasMore: end < filtered.length,
      );
    }
  }

  Future<void> createCustomer({
    required String fullName,
    required String gender,
    String? phoneNumber,
    String? notes,
  }) async {
    final body = {
      'full_name': fullName,
      'gender': gender,
      'phone_number': phoneNumber,
      'notes': notes,
    };
    try {
      await _dio.post('/api/customers', data: body);
      await _offlineSync.processQueue();
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        final data = e.response?.data;
        if (data is Map && (data['error'] == 'duplicate_name')) {
          throw DuplicateCustomerException(
            existingCustomerId: (data['existing_customer_id'] ?? '').toString(),
            customerName: fullName,
            message: (data['message'] ?? '').toString(),
          );
        }
      }
      await _offlineSync.enqueue(method: 'POST', path: '/api/customers', data: body);
    }
  }

  Future<void> updateCustomer({
    required String customerId,
    required String fullName,
    required String gender,
    String? phoneNumber,
    String? notes,
    DateTime? lastKnownModifiedAt,
  }) async {
    final body = {
      'customer_id': customerId,
      'full_name': fullName,
      'gender': gender,
      'phone_number': phoneNumber,
      'notes': notes,
      if (lastKnownModifiedAt != null) 'client_last_modified_at': lastKnownModifiedAt.toIso8601String(),
    };
    try {
      await _dio.patch('/api/customers', data: body);
      await _offlineSync.processQueue();
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        final data = e.response?.data;
        if (data is Map && (data['error'] == 'duplicate_name')) {
          throw DuplicateCustomerException(
            existingCustomerId: (data['existing_customer_id'] ?? '').toString(),
            customerName: fullName,
            message: (data['message'] ?? '').toString(),
          );
        }
      }
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
    DateTime? lastKnownModifiedAt,
  }) async {
    final body = {
      'measurement_id': measurementId,
      'taken_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(takenAt),
      'payload': payload,
      if (lastKnownModifiedAt != null) 'client_last_modified_at': lastKnownModifiedAt.toIso8601String(),
    };
    try {
      await _dio.patch('/api/measurements', data: body);
      await _offlineSync.processQueue();
    } catch (_) {
      await _offlineSync.enqueue(method: 'PATCH', path: '/api/measurements', data: body);
    }
  }
}

class CustomersPage {
  const CustomersPage({
    required this.items,
    required this.total,
    required this.hasMore,
  });

  final List<Customer> items;
  final int total;
  final bool hasMore;
}
