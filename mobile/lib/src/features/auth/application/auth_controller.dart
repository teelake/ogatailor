import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/offline_sync_service.dart';
import '../data/auth_repository.dart';
import '../domain/auth_session.dart';

class AuthController extends StateNotifier<AsyncValue<AuthSession?>> {
  AuthController(this._repository, this._offlineSync) : super(const AsyncValue.loading()) {
    _init();
  }

  final AuthRepository _repository;
  final OfflineSyncService _offlineSync;

  Future<void> _init() async {
    final session = await _repository.restoreSession();
    state = AsyncValue.data(session);
  }

  Future<void> startGuest() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _repository.startGuest(
        deviceName: 'Tailor Device',
      ),
    );
  }

  Future<void> register({
    required String fullName,
    String? phoneNumber,
    String? businessName,
    required String email,
    required String password,
  }) async {
    final current = state.valueOrNull;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _repository.register(
        fullName: fullName,
        phoneNumber: phoneNumber,
        businessName: businessName,
        email: email,
        password: password,
        guestUserId: current?.mode == 'guest' ? current?.userId : null,
      ),
    );
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final session = await _repository.login(email: email, password: password);
      await _offlineSync.clearUserData();
      return session;
    });
  }

  Future<void> logout() async {
    await _repository.clearSession();
    state = const AsyncValue.data(null);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<AuthSession?>>((ref) {
  return AuthController(
    ref.watch(authRepositoryProvider),
    ref.read(offlineSyncServiceProvider),
  );
});
