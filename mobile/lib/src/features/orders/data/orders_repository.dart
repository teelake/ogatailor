import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/notifications/order_reminder_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/sync/offline_sync_service.dart';
import '../../../core/utils/error_message.dart';
import '../domain/order_entry.dart';

class OrdersRepository {
  OrdersRepository(this._dio, this._offlineSync, this._reminders);

  final Dio _dio;
  final OfflineSyncService _offlineSync;
  final OrderReminderService _reminders;

  Future<List<OrderEntry>> listOrders() async {
    final hasPremiumAccess = await _fetchHasPremiumAccess();
    try {
      final response = await _dio.get('/api/orders');
      final data = Map<String, dynamic>.from(response.data as Map);
      final rows = List<Map<String, dynamic>>.from(data['data'] as List<dynamic>);
      await _offlineSync.saveCache('cache_orders', rows);
      final orders = rows.map(OrderEntry.fromJson).toList();
      await _reminders.syncAll(
        orders,
        hasPremiumAccess: hasPremiumAccess,
      );
      return orders;
    } catch (_) {
      final rows = await _offlineSync.readCache('cache_orders');
      final orders = rows.map(OrderEntry.fromJson).toList();
      await _reminders.syncAll(
        orders,
        hasPremiumAccess: hasPremiumAccess,
      );
      return orders;
    }
  }

  Future<bool> createOrder({
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
      final response = await _dio.post('/api/orders', data: body);
      final data = Map<String, dynamic>.from(response.data as Map);
      final orderId = (data['id'] ?? '').toString();
      if (orderId.isNotEmpty) {
        final hasPremiumAccess = await _fetchHasPremiumAccess();
        await _reminders.scheduleForOrder(
          OrderEntry(
            id: orderId,
            customerId: customerId,
            customerName: 'Customer',
            title: title,
            status: status,
            amountTotal: amountTotal,
            dueDate: dueDate,
            notes: notes,
          ),
          hasPremiumAccess: hasPremiumAccess,
        );
      }
      await _offlineSync.processQueue();
      return false;
    } on DioException catch (error) {
      if (isConnectivityIssue(error)) {
        await _offlineSync.enqueue(method: 'POST', path: '/api/orders', data: body);
        return true;
      }
      rethrow;
    }
  }

  Future<void> updateStatus({
    required String orderId,
    required String status,
    DateTime? lastKnownModifiedAt,
  }) async {
    final body = {
      'order_id': orderId,
      'status': status,
      if (lastKnownModifiedAt != null) 'client_last_modified_at': lastKnownModifiedAt.toIso8601String(),
    };
    try {
      await _dio.patch('/api/orders/status', data: body);
      if (status == 'delivered' || status == 'cancelled') {
        await _reminders.cancelForOrder(orderId);
      } else {
        await _refreshRemindersFromServer();
      }
      await _offlineSync.processQueue();
    } on DioException catch (error) {
      if (isConnectivityIssue(error)) {
        await _offlineSync.enqueue(method: 'PATCH', path: '/api/orders/status', data: body);
        return;
      }
      rethrow;
    }
  }

  Future<void> updateDueDate({
    required String orderId,
    DateTime? dueDate,
    DateTime? lastKnownModifiedAt,
  }) async {
    final body = {
      'order_id': orderId,
      'due_date': dueDate == null ? '' : DateFormat('yyyy-MM-dd HH:mm:ss').format(dueDate),
      if (lastKnownModifiedAt != null) 'client_last_modified_at': lastKnownModifiedAt.toIso8601String(),
    };
    try {
      await _dio.patch('/api/orders/due-date', data: body);
      await _refreshRemindersFromServer();
      await _offlineSync.processQueue();
    } on DioException catch (error) {
      if (isConnectivityIssue(error)) {
        await _offlineSync.enqueue(method: 'PATCH', path: '/api/orders/due-date', data: body);
        return;
      }
      rethrow;
    }
  }

  Future<void> _refreshRemindersFromServer() async {
    try {
      final hasPremiumAccess = await _fetchHasPremiumAccess();
      final response = await _dio.get('/api/orders');
      final data = Map<String, dynamic>.from(response.data as Map);
      final rows = List<Map<String, dynamic>>.from(data['data'] as List<dynamic>);
      final orders = rows.map(OrderEntry.fromJson).toList();
      await _reminders.syncAll(
        orders,
        hasPremiumAccess: hasPremiumAccess,
      );
    } catch (_) {
      // Do not block user flow when reminders refresh fails.
    }
  }

  Future<bool> _fetchHasPremiumAccess() async {
    try {
      final response = await _dio.get('/api/plan/summary');
      final data = Map<String, dynamic>.from(response.data as Map);
      final code = (data['plan_code'] ?? 'starter').toString();
      return code == 'growth' || code == 'pro';
    } catch (_) {
      // Safe fallback: enforce Starter reminder policy if plan cannot be fetched.
      return false;
    }
  }
}

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository(
    ref.watch(dioProvider),
    ref.watch(offlineSyncServiceProvider),
    ref.watch(orderReminderServiceProvider),
  );
});
