import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/sync/offline_sync_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/auth/presentation/welcome_screen.dart';
import 'features/customers/presentation/customers_screen.dart';

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
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(offlineSyncServiceProvider).processQueue();
      ref.invalidate(syncStatusProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const CustomersScreen();
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
