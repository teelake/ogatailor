import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/plan_summary.dart';
import '../domain/plan_tier.dart';

class PlanRepository {
  PlanRepository(this._dio);

  final Dio _dio;

  Future<PlanSummary> fetchSummary() async {
    final response = await _dio.get('/api/plan/summary');
    final data = Map<String, dynamic>.from(response.data as Map);
    return PlanSummary(
      planCode: (data['plan_code'] ?? 'starter') as String,
      customerCount: (data['customer_count'] ?? 0) as int,
      customerLimit: data['customer_limit'] as int?,
      invoicesUsedThisMonth: (data['invoices_used_this_month'] ?? 0) as int,
      invoicesPerMonth: data['invoices_per_month'] as int?,
    );
  }

  Future<List<PlanTier>> fetchPlans() async {
    final response = await _dio.get('/api/plans');
    final data = Map<String, dynamic>.from(response.data as Map);
    final list = (data['plans'] as List?) ?? [];
    return list.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return PlanTier(
        planCode: (m['plan_code'] ?? 'starter') as String,
        displayName: (m['display_name'] ?? 'Starter') as String,
        customerLimit: m['customer_limit'] as int?,
        customerLimitLabel: (m['customer_limit_label'] ?? '') as String,
        invoicesPerMonth: m['invoices_per_month'] as int?,
        priceNgn: (m['price_ngn'] ?? 0) as int,
        features: ((m['features'] as List?) ?? []).map((x) => x.toString()).toList(),
      );
    }).toList();
  }

  Future<Map<String, String>> initializeUpgrade(String planCode) async {
    final response = await _dio.post(
      '/api/plans/upgrade-initialize',
      data: {'plan_code': planCode},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return {
      'authorization_url': (data['authorization_url'] ?? '') as String,
      'reference': (data['reference'] ?? '') as String,
    };
  }
}

final planRepositoryProvider = Provider<PlanRepository>((ref) {
  return PlanRepository(ref.watch(dioProvider));
});
