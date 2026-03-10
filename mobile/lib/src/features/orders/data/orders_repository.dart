import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../domain/order_entry.dart';

class OrdersRepository {
  OrdersRepository(this._dio);

  final Dio _dio;

  Future<List<OrderEntry>> listOrders({required String ownerUserId}) async {
    final response = await _dio.get(
      '/api/orders',
      queryParameters: {'owner_user_id': ownerUserId},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final rows = List<Map<String, dynamic>>.from(data['data'] as List<dynamic>);
    return rows.map(OrderEntry.fromJson).toList();
  }

  Future<void> createOrder({
    required String ownerUserId,
    required String customerId,
    required String title,
    required String status,
    required double amountTotal,
    String? notes,
    DateTime? dueDate,
  }) async {
    await _dio.post(
      '/api/orders',
      data: {
        'owner_user_id': ownerUserId,
        'customer_id': customerId,
        'title': title,
        'status': status,
        'amount_total': amountTotal,
        'notes': notes,
        'due_date': dueDate == null ? null : DateFormat('yyyy-MM-dd HH:mm:ss').format(dueDate),
      },
    );
  }

  Future<void> updateStatus({
    required String ownerUserId,
    required String orderId,
    required String status,
  }) async {
    await _dio.patch(
      '/api/orders/status',
      data: {
        'owner_user_id': ownerUserId,
        'order_id': orderId,
        'status': status,
      },
    );
  }

  Future<void> updateDueDate({
    required String ownerUserId,
    required String orderId,
    DateTime? dueDate,
  }) async {
    await _dio.patch(
      '/api/orders/due-date',
      data: {
        'owner_user_id': ownerUserId,
        'order_id': orderId,
        'due_date': dueDate == null ? '' : DateFormat('yyyy-MM-dd HH:mm:ss').format(dueDate),
      },
    );
  }
}

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository(ref.watch(dioProvider));
});
