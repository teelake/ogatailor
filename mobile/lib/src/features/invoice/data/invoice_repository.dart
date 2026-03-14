import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

class InvoiceRepository {
  InvoiceRepository(this._dio);

  final Dio _dio;

  /// Generate invoice from order. Returns invoice data or throws.
  Future<Map<String, dynamic>> generateFromOrder(String orderId) async {
    final response = await _dio.post(
      '/api/invoices/generate',
      data: {'order_id': orderId},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Fetch invoice by order ID.
  Future<Map<String, dynamic>> getByOrderId(String orderId) async {
    final response = await _dio.get(
      '/api/invoices/by-order',
      queryParameters: {'order_id': orderId},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return Map<String, dynamic>.from((data['data'] ?? <String, dynamic>{}) as Map);
  }

  /// Fetch business profile.
  Future<Map<String, dynamic>?> getBusinessProfile() async {
    try {
      final response = await _dio.get('/api/business-profile');
      final data = Map<String, dynamic>.from(response.data as Map);
      return Map<String, dynamic>.from((data['data'] ?? <String, dynamic>{}) as Map);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Save business profile (invoice KYC).
  Future<void> saveBusinessProfile({
    required String businessName,
    String? businessPhone,
    String? businessEmail,
    String? businessAddress,
    required bool cacRegistered,
    String? cacRegistrationType,
    String? cacNumber,
    required bool vatEnabled,
    double defaultVatRate = 0,
    String currency = 'NGN',
    String? paymentTerms,
    String? logoData,
  }) async {
    final payload = <String, dynamic>{
      'business_name': businessName,
      'business_phone': businessPhone,
      'business_email': businessEmail,
      'business_address': businessAddress,
      'cac_registered': cacRegistered,
      'cac_registration_type': cacRegistrationType,
      'cac_number': cacNumber,
      'vat_enabled': vatEnabled,
      'default_vat_rate': defaultVatRate,
      'currency': currency,
      'payment_terms': paymentTerms,
      'logo_data': logoData,
    };
    await _dio.patch('/api/business-profile', data: payload);
  }
}

final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  return InvoiceRepository(ref.watch(dioProvider));
});
