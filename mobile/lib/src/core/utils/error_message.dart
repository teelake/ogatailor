import 'package:dio/dio.dart';

String userFriendlyError(Object error, {String fallback = 'Something went wrong. Please try again.'}) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final message = (data['message'] ?? data['error'] ?? '').toString().trim();
      if (message.isNotEmpty) {
        return _normalizeMessage(message);
      }
    }
  }

  final raw = error.toString().trim();
  if (raw.isEmpty) return fallback;
  if (raw.startsWith('Exception:')) {
    return _normalizeMessage(raw.replaceFirst('Exception:', '').trim());
  }
  return _normalizeMessage(raw);
}

String _normalizeMessage(String message) {
  final m = message.replaceAll('_', ' ').trim();
  if (m.isEmpty) return 'Something went wrong. Please try again.';
  return m[0].toUpperCase() + m.substring(1);
}
