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
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              _Logo(),
              const SizedBox(height: 24),
              Text(
                'Your Clients\' Measurements,\nAlways at Hand',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'For tailors and seamstresses. Save customer measurements, track fitting history, and manage orders—all on your phone. Works offline.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              _FeatureHighlights(),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => ref.read(authControllerProvider.notifier).startGuest(),
                icon: const Icon(Icons.offline_bolt_rounded),
                label: const Text('Continue as Guest'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
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
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(Icons.straighten_rounded, color: AppColors.primary, size: 40),
        ),
        const SizedBox(height: 12),
        Text(
          'Oga Tailor',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _FeatureHighlights extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.person_add_rounded, 'Add customers'),
      (Icons.straighten_rounded, 'Save measurements'),
      (Icons.history_rounded, 'Track history'),
      (Icons.offline_bolt_rounded, 'Works offline'),
    ];

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.$1, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                item.$2,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppColors.primaryDark,
                    ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
