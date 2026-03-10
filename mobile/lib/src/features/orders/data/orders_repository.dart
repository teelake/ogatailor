import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/sync/offline_sync_service.dart';
import '../domain/order_entry.dart';

class OrdersRepository {
  OrdersRepository(this._dio, this._offlineSync);

  final Dio _dio;
  final OfflineSyncService _offlineSync;

  Future<List<OrderEntry>> listOrders() async {
    try {
      final response = await _dio.get('/api/orders');
      final data = Map<String, dynamic>.from(response.data as Map);
      final rows = List<Map<String, dynamic>>.from(data['data'] as List<dynamic>);
      await _offlineSync.saveCache('cache_orders', rows);
      return rows.map(OrderEntry.fromJson).toList();
    } catch (_) {
      final rows = await _offlineSync.readCache('cache_orders');
      return rows.map(OrderEntry.fromJson).toList();
    }
  }

  Future<void> createOrder({
    required String customerId,
    required String title,
    required String status,
    required double amountTotal,
    String? notes,
    DateTime? dueDate,
  }) async {
    final body = {
      'customer_id': customerId,
      'title': title,
      'status': status,
      'amount_total': amountTotal,
      'notes': notes,
      'due_date': dueDate == null ? null : DateFormat('yyyy-MM-dd HH:mm:ss').format(dueDate),
    };
    try {
      await _dio.post('/api/orders', data: body);
      await _offlineSync.processQueue();
    } catch (_) {
      await _offlineSync.enqueue(method: 'POST', path: '/api/orders', data: body);
    }
  }

  Future<void> updateStatus({
    required String orderId,
    required String status,
  }) async {
    final body = {'order_id': orderId, 'status': status};
    try {
      await _dio.patch('/api/orders/status', data: body);
      await _offlineSync.processQueue();
    } catch (_) {
      await _offlineSync.enqueue(method: 'PATCH', path: '/api/orders/status', data: body);
    }
  }

  Future<void> updateDueDate({
    required String orderId,
    DateTime? dueDate,
  }) async {
    final body = {
      'order_id': orderId,
      'due_date': dueDate == null ? '' : DateFormat('yyyy-MM-dd HH:mm:ss').format(dueDate),
    };
    try {
      await _dio.patch('/api/orders/due-date', data: body);
      await _offlineSync.processQueue();
    } catch (_) {
      await _offlineSync.enqueue(method: 'PATCH', path: '/api/orders/due-date', data: body);
    }
  }
}

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository(ref.watch(dioProvider), ref.watch(offlineSyncServiceProvider));
});
