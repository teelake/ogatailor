import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../application/auth_controller.dart';
import 'auth_sheet.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.design_services_rounded, color: AppColors.primary, size: 36),
              ),
              const SizedBox(height: 20),
              Text(
                'Welcome to Oga Tailor',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Start instantly in offline mode. Create an account later for cloud backup and restore.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => ref.read(authControllerProvider.notifier).startGuest(),
                icon: const Icon(Icons.offline_bolt_rounded),
                label: const Text('Continue as Guest'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => showAuthSheet(context, mode: AuthSheetMode.login),
                child: const Text('Sign In'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => showAuthSheet(context, mode: AuthSheetMode.register),
                child: const Text('Create Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
