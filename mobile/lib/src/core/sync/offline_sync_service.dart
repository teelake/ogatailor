import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_client.dart';

class OfflineSyncService {
  static const _kPendingOps = 'sync_pending_ops';
  static const _kStatus = 'sync_status';
  static const _kLastError = 'sync_last_error';
  static const _kConflicts = 'sync_conflicts';

  final Dio _dio;

  OfflineSyncService(this._dio);

  Future<void> saveCache(String key, List<Map<String, dynamic>> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(rows));
  }

  Future<List<Map<String, dynamic>>> readCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return [];
    }
    return decoded.map<Map<String, dynamic>>((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<void> enqueue({
    required String method,
    required String path,
    Map<String, dynamic>? data,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = await pendingOperations();
    queue.add({
      'method': method,
      'path': path,
      'data': data ?? <String, dynamic>{},
      'attempts': 0,
      'queued_at': DateTime.now().toIso8601String(),
    });
    await prefs.setString(_kPendingOps, jsonEncode(queue));
    await prefs.setString(_kStatus, 'pending');
  }

  Future<List<Map<String, dynamic>>> pendingOperations() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPendingOps);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return [];
    }
    return decoded.map<Map<String, dynamic>>((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<void> processQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final queue = await pendingOperations();
    if (queue.isEmpty) {
      await prefs.setString(_kStatus, 'synced');
      await prefs.remove(_kLastError);
      return;
    }

    await prefs.setString(_kStatus, 'syncing');
    final conflicts = await syncConflicts();
    final remaining = <Map<String, dynamic>>[];
    for (final op in queue) {
      try {
        await _dio.request(
          op['path'] as String,
          data: Map<String, dynamic>.from((op['data'] ?? <String, dynamic>{}) as Map),
          options: Options(method: (op['method'] as String?) ?? 'POST'),
        );
      } on DioException catch (error) {
        final statusCode = error.response?.statusCode ?? 0;
        if (statusCode == 409) {
          final response = error.response?.data;
          final map = response is Map ? Map<String, dynamic>.from(response) : <String, dynamic>{};
          conflicts.add({
            'method': op['method'],
            'path': op['path'],
            'data': op['data'],
            'queued_at': op['queued_at'],
            'occurred_at': DateTime.now().toIso8601String(),
            'server': map,
          });
          await prefs.setString(_kStatus, 'conflict');
          await prefs.setString(_kLastError, 'Conflict detected. Review and resolve.');
          continue;
        }
        final attempts = ((op['attempts'] ?? 0) as int) + 1;
        op['attempts'] = attempts;
        remaining.add(op);
        await prefs.setString(_kStatus, 'failed');
        await prefs.setString(_kLastError, error.toString());
      } catch (error) {
        final attempts = ((op['attempts'] ?? 0) as int) + 1;
        op['attempts'] = attempts;
        remaining.add(op);
        await prefs.setString(_kStatus, 'failed');
        await prefs.setString(_kLastError, error.toString());
      }
    }

    await prefs.setString(_kPendingOps, jsonEncode(remaining));
    await prefs.setString(_kConflicts, jsonEncode(conflicts));
    if (remaining.isEmpty) {
      if (conflicts.isEmpty) {
        await prefs.setString(_kStatus, 'synced');
        await prefs.remove(_kLastError);
      } else {
        await prefs.setString(_kStatus, 'conflict');
      }
    }
  }

  Future<List<Map<String, dynamic>>> syncConflicts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kConflicts);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded.map<Map<String, dynamic>>((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<void> clearConflicts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kConflicts);
    final pending = await pendingOperations();
    await prefs.setString(_kStatus, pending.isEmpty ? 'synced' : 'pending');
  }

  Future<Map<String, dynamic>> status() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = await pendingOperations();
    return {
      'state': prefs.getString(_kStatus) ?? 'synced',
      'pending_count': pending.length,
      'last_error': prefs.getString(_kLastError),
      'conflict_count': (await syncConflicts()).length,
    };
  }
}

final offlineSyncServiceProvider = Provider<OfflineSyncService>((ref) {
  return OfflineSyncService(ref.watch(dioProvider));
});

final syncStatusProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(offlineSyncServiceProvider).status();
});

final syncConflictsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(offlineSyncServiceProvider).syncConflicts();
});
