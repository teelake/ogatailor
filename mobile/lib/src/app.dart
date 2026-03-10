import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        data: (session) => session == null ? const WelcomeScreen() : const CustomersScreen(),
      ),
    );
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
