import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/notifications/order_reminder_service.dart';
import 'core/sync/offline_sync_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/auth/presentation/welcome_screen.dart';
import 'presentation/main_shell.dart';

class OgaTailorApp extends ConsumerWidget {
  const OgaTailorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return MaterialApp(
      title: 'Oga Tailor',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: authState.when(
        loading: () => const _BootScreen(),
        error: (_, __) => const WelcomeScreen(),
        data: (session) => session == null ? const WelcomeScreen() : const _AuthenticatedHome(),
      ),
    );
  }
}

class _AuthenticatedHome extends ConsumerStatefulWidget {
  const _AuthenticatedHome();

  @override
  ConsumerState<_AuthenticatedHome> createState() => _AuthenticatedHomeState();
}

class _AuthenticatedHomeState extends ConsumerState<_AuthenticatedHome> {
  static const _syncInterval = Duration(minutes: 5);
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    Future.microtask(_syncNow);
    _syncTimer = Timer.periodic(_syncInterval, (_) async {
      if (!mounted) return;
      await _syncNow();
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _syncNow() async {
    await ref.read(orderReminderServiceProvider).initialize();
    await ref.read(offlineSyncServiceProvider).processQueue();
    if (mounted) ref.invalidate(syncStatusProvider);
  }

  @override
  Widget build(BuildContext context) {
    return const MainShell();
  }
}

class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
