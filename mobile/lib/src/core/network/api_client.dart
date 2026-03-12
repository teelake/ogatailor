import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _defaultApiBaseUrl = 'https://webspace.ng/oga-tailor';

String _resolvedApiBaseUrl() {
  final configured = const String.fromEnvironment('API_BASE_URL', defaultValue: _defaultApiBaseUrl).trim();
  final normalized = configured.isEmpty ? _defaultApiBaseUrl : configured;
  return normalized.endsWith('/') ? normalized.substring(0, normalized.length - 1) : normalized;
}

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: _resolvedApiBaseUrl(),
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('session_token');
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ),
  );

  return dio;
});
