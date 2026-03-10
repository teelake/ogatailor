import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/plan_summary.dart';

class PlanRepository {
  PlanRepository(this._dio);

  final Dio _dio;

  Future<PlanSummary> fetchSummary({required String ownerUserId}) async {
    final response = await _dio.get(
      '/api/plan/summary',
      queryParameters: {'owner_user_id': ownerUserId},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return PlanSummary(
      planCode: (data['plan_code'] ?? 'free') as String,
      customerCount: (data['customer_count'] ?? 0) as int,
      customerLimit: data['customer_limit'] as int?,
    );
  }
}

final planRepositoryProvider = Provider<PlanRepository>((ref) {
  return PlanRepository(ref.watch(dioProvider));
});
