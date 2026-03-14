import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

class AppConfig {
  const AppConfig({
    required this.platformUrl,
    this.platformLogoUrl,
    this.supportEmail,
    this.supportPhone,
    required this.invoiceDefaults,
    required this.logoConstraints,
    required this.currencies,
  });

  final String platformUrl;
  final String? platformLogoUrl;
  final String? supportEmail;
  final String? supportPhone;
  final InvoiceDefaults invoiceDefaults;
  final LogoConstraints logoConstraints;
  final List<PlatformCurrency> currencies;
}

class PlatformCurrency {
  const PlatformCurrency({
    required this.code,
    required this.symbol,
    required this.name,
  });

  final String code;
  final String symbol;
  final String name;
}

class InvoiceDefaults {
  const InvoiceDefaults({
    required this.currency,
    required this.vatRate,
    required this.paymentTerms,
  });

  final String currency;
  final double vatRate;
  final String paymentTerms;
}

class LogoConstraints {
  const LogoConstraints({
    required this.maxSizeKb,
    required this.minDimension,
    required this.maxDimension,
  });

  final int maxSizeKb;
  final int minDimension;
  final int maxDimension;
}

class ConfigRepository {
  ConfigRepository(this._dio);

  final Dio _dio;

  Future<AppConfig> fetchConfig() async {
    final response = await _dio.get('/api/config');
    final data = Map<String, dynamic>.from(response.data as Map);
    final defaults = (data['invoice_defaults'] ?? {}) as Map;
    final constraints = (data['logo_constraints'] ?? {}) as Map;
    final currenciesList = (data['currencies'] as List?) ?? [];
    var currencies = currenciesList.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return PlatformCurrency(
        code: (m['code'] ?? '').toString(),
        symbol: (m['symbol'] ?? m['code'] ?? '').toString(),
        name: (m['name'] ?? m['code'] ?? '').toString(),
      );
    }).toList();
    if (currencies.isEmpty) {
      currencies = [
        const PlatformCurrency(code: 'NGN', symbol: '₦', name: 'Nigerian Naira'),
        const PlatformCurrency(code: 'USD', symbol: '\$', name: 'US Dollar'),
        const PlatformCurrency(code: 'GBP', symbol: '£', name: 'British Pound'),
      ];
    }
    return AppConfig(
      platformUrl: (data['platform_url'] ?? 'https://ogatailor.app') as String,
      platformLogoUrl: data['platform_logo_url'] as String?,
      supportEmail: data['support_email'] as String?,
      supportPhone: data['support_phone'] as String?,
      invoiceDefaults: InvoiceDefaults(
        currency: (defaults['currency'] ?? 'NGN') as String,
        vatRate: ((defaults['vat_rate'] ?? 7.5) as num).toDouble(),
        paymentTerms: (defaults['payment_terms'] ?? 'Payment due within 7 days') as String,
      ),
      logoConstraints: LogoConstraints(
        maxSizeKb: (constraints['max_size_kb'] ?? 500) as int,
        minDimension: (constraints['min_dimension'] ?? 64) as int,
        maxDimension: (constraints['max_dimension'] ?? 512) as int,
      ),
      currencies: currencies,
    );
  }
}

final configRepositoryProvider = Provider<ConfigRepository>((ref) {
  return ConfigRepository(ref.watch(dioProvider));
});
