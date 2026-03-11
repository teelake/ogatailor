import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../domain/auth_session.dart';

class AuthController extends StateNotifier<AsyncValue<AuthSession?>> {
  AuthController(this._repository) : super(const AsyncValue.loading()) {
    _init();
  }

  final AuthRepository _repository;

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
    required String email,
    required String password,
  }) async {
    final current = state.valueOrNull;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _repository.register(
        fullName: fullName,
        phoneNumber: phoneNumber,
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
    state = await AsyncValue.guard(() => _repository.login(email: email, password: password));
  }

  Future<void> logout() async {
    await _repository.clearSession();
    state = const AsyncValue.data(null);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<AuthSession?>>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});
