import 'package:dio/dio.dart';

String userFriendlyError(Object error, {String fallback = 'Something went wrong. Please try again.'}) {
  if (error is DioException) {
    final statusCode = error.response?.statusCode;
    // Prefer status-based messages over parse errors (e.g. 500 HTML error page)
    if (statusCode == 500) {
      return 'Server is currently unavailable. Please try again shortly.';
    }
    if (error.error is FormatException) {
      return 'Invalid response from server. Please try again.';
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Request timed out. Please check your internet and try again.';
    }
    if (error.type == DioExceptionType.connectionError) {
      return 'Could not connect to server. Check your internet connection and try again.';
    }
    if (statusCode == 401) {
      return 'Invalid email or password. Please try again.';
    }
    if (statusCode == 403) {
      return 'You do not have access to perform this action.';
    }
    if (statusCode == 404) {
      return 'Requested resource was not found.';
    }
    if (statusCode == 429) {
      return 'Too many requests. Please wait a moment and try again.';
    }
    if (statusCode != null && statusCode >= 500) {
      return 'Server is currently unavailable. Please try again shortly.';
    }

    final data = error.response?.data;
    if (data is Map) {
      final message = (data['message'] ?? data['error'] ?? '').toString().trim();
      if (message.isNotEmpty) {
        return _normalizeMessage(message);
      }
    }
  }

  if (error is FormatException) {
    return 'Invalid response from server. Please try again.';
  }

  final raw = error.toString().trim();
  if (raw.isEmpty) return fallback;
  if (raw.startsWith('Exception:')) {
    return _normalizeMessage(raw.replaceFirst('Exception:', '').trim());
  }
  return _normalizeMessage(raw);
}

bool isConnectivityIssue(Object error) {
  if (error is DioException) {
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError;
  }
  return false;
}

String _normalizeMessage(String message) {
  final m = message.replaceAll('_', ' ').trim();
  if (m.isEmpty) return 'Something went wrong. Please try again.';
  return m[0].toUpperCase() + m.substring(1);
}
