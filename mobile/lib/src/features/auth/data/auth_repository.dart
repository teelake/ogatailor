import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../domain/auth_session.dart';

class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  static const _kUserId = 'session_user_id';
  static const _kToken = 'session_token';
  static const _kMode = 'session_mode';
  static const _kGuestDeviceId = 'guest_device_id';

  Future<AuthSession?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_kUserId);
    final token = prefs.getString(_kToken);
    final mode = prefs.getString(_kMode);
    if (userId == null || token == null || mode == null) {
      return null;
    }
    return AuthSession(userId: userId, token: token, mode: mode);
  }

  Future<void> clearSession() async {
    try {
      await _dio.post('/api/auth/logout');
    } catch (_) {
      // Non-blocking: clear local session regardless.
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserId);
    await prefs.remove(_kToken);
    await prefs.remove(_kMode);
  }

  Future<AuthSession> startGuest({required String deviceName}) async {
    final deviceId = await _getOrCreateGuestDeviceId();
    final response = await _dio.post(
      '/api/auth/guest-start',
      data: {
        'device_id': deviceId,
        'device_name': deviceName,
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final session = AuthSession(
      userId: data['user_id'] as String,
      token: data['token'] as String,
      mode: data['mode'] as String,
    );
    await _persistSession(session);
    return session;
  }

  Future<String> _getOrCreateGuestDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_kGuestDeviceId);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final random = Random.secure();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final nonce = random.nextInt(1 << 32).toRadixString(16);
    final deviceId = 'dev-$ts-$nonce';
    await prefs.setString(_kGuestDeviceId, deviceId);
    return deviceId;
  }

  Future<AuthSession> register({
    required String fullName,
    String? phoneNumber,
    required String email,
    required String password,
    String? guestUserId,
  }) async {
    final response = await _dio.post(
      '/api/auth/register',
      data: {
        'full_name': fullName,
        'phone_number': phoneNumber,
        'email': email,
        'password': password,
        if (guestUserId != null && guestUserId.isNotEmpty) 'guest_user_id': guestUserId,
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final session = AuthSession(
      userId: data['user_id'] as String,
      token: data['token'] as String,
      mode: data['mode'] as String,
    );
    await _persistSession(session);
    return session;
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(
      '/api/auth/login',
      data: {
        'email': email,
        'password': password,
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final session = AuthSession(
      userId: data['user_id'] as String,
      token: data['token'] as String,
      mode: data['mode'] as String,
    );
    await _persistSession(session);
    return session;
  }

  Future<Map<String, dynamic>> fetchProfile() async {
    final response = await _dio.get('/api/auth/profile');
    final data = Map<String, dynamic>.from(response.data as Map);
    return Map<String, dynamic>.from((data['data'] ?? <String, dynamic>{}) as Map);
  }

  Future<void> updateProfile({
    required String fullName,
    required String email,
    String? phoneNumber,
  }) async {
    await _dio.patch(
      '/api/auth/profile',
      data: {
        'full_name': fullName,
        'email': email,
        'phone_number': phoneNumber,
      },
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _dio.post(
      '/api/auth/change-password',
      data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      },
    );
  }

  Future<String> forgotPassword({required String email}) async {
    final response = await _dio.post(
      '/api/auth/forgot-password',
      data: {'email': email},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return (data['reset_code'] ?? '').toString();
  }

  Future<void> resetPassword({
    required String email,
    required String resetCode,
    required String newPassword,
  }) async {
    await _dio.post(
      '/api/auth/reset-password',
      data: {
        'email': email,
        'reset_code': resetCode,
        'new_password': newPassword,
      },
    );
  }

  Future<void> _persistSession(AuthSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserId, session.userId);
    await prefs.setString(_kToken, session.token);
    await prefs.setString(_kMode, session.mode);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return AuthRepository(dio);
});
