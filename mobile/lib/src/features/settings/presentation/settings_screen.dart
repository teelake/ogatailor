import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/change_password_screen.dart';
import '../../auth/presentation/edit_profile_screen.dart';
import '../../orders/application/orders_controller.dart';
import '../../plan/application/plan_controller.dart';
import '../../plan/presentation/upgrade_screen.dart';
import '../../reports/presentation/export_reports_screen.dart';
import '../../../core/preferences/measurement_unit_provider.dart';
import '../../../core/preferences/order_reminder_preferences_provider.dart';
import '../../../core/theme/app_colors.dart';

/// Settings screen: Edit Profile, Change Password, Upgrade Plan, Log out.
/// Accessible from the bottom nav for easy discovery.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planSummaryAsync = ref.watch(planSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _SettingsSection(
            title: 'Account',
            children: [
              _SettingsTile(
                icon: Icons.person_rounded,
                title: 'Edit Profile',
                subtitle: 'Update your name, email, and phone',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                ),
              ),
              _SettingsTile(
                icon: Icons.lock_rounded,
                title: 'Change Password',
                subtitle: 'Update your password',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                ),
              ),
            ],
          ),
          _SettingsSection(
            title: 'Preferences',
            children: [
              _MeasurementUnitTile(),
              _OrderReminderTile(),
            ],
          ),
          _SettingsSection(
            title: 'Plan',
            children: [
              _SettingsTile(
                icon: Icons.workspace_premium_rounded,
                title: 'Upgrade Plan',
                subtitle: planSummaryAsync.valueOrNull?.hasPremiumAccess == true
                    ? '${planSummaryAsync.valueOrNull?.displayName ?? 'Premium'} plan active'
                    : 'Unlock Growth/Pro: cloud backup, export, and more customers',
                trailing: planSummaryAsync.valueOrNull?.hasPremiumAccess == true
                    ? _PlanBadge(label: planSummaryAsync.valueOrNull?.displayName ?? 'Premium')
                    : null,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const UpgradeScreen()),
                ),
              ),
              _SettingsTile(
                icon: Icons.file_download_rounded,
                title: 'Export Reports',
                subtitle: 'Generate measurement summary and CSV reports',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ExportReportsScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () async {
                await ref.read(authControllerProvider.notifier).logout();
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Log out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade300),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        ...children,
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _MeasurementUnitTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(measurementUnitProvider);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.straighten_rounded, color: AppColors.primary),
                const SizedBox(width: 12),
                Text(
                  'Measurement unit',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<MeasurementUnit>(
              segments: const [
                ButtonSegment(
                  value: MeasurementUnit.inches,
                  label: Text('Inches'),
                  icon: Icon(Icons.straighten_rounded, size: 18),
                ),
                ButtonSegment(
                  value: MeasurementUnit.cm,
                  label: Text('Centimetres'),
                  icon: Icon(Icons.straighten_rounded, size: 18),
                ),
              ],
              selected: {unit},
              onSelectionChanged: (selected) {
                ref.read(measurementUnitProvider.notifier).setUnit(selected.first);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accentGold.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.accentGold,
        ),
      ),
    );
  }
}

class _OrderReminderTile extends ConsumerWidget {
  static const _advancedOffsets = [14, 7, 3, 1, 0];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(orderReminderPreferencesProvider);
    final planSummary = ref.watch(planSummaryProvider).valueOrNull;
    final isPremium = planSummary?.hasPremiumAccess ?? false;

    Future<void> reschedule() async {
      ref.invalidate(ordersProvider);
      try {
        await ref.read(ordersProvider.future);
      } catch (_) {
        // Non-blocking: scheduler will retry when orders refresh next.
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_active_rounded, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Order due reminders',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Switch(
                  value: prefs.enabled,
                  onChanged: (v) async {
                    await ref.read(orderReminderPreferencesProvider.notifier).setEnabled(v);
                    await reschedule();
                  },
                ),
              ],
            ),
            if (!prefs.enabled) ...[
              const SizedBox(height: 4),
              const Text('Reminders are turned off'),
            ] else ...[
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Reminder time'),
                subtitle: Text('${prefs.hour.toString().padLeft(2, '0')}:${prefs.minute.toString().padLeft(2, '0')}'),
                trailing: const Icon(Icons.schedule_rounded),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(hour: prefs.hour, minute: prefs.minute),
                  );
                  if (picked != null) {
                    await ref.read(orderReminderPreferencesProvider.notifier).setTime(picked.hour, picked.minute);
                    await reschedule();
                  }
                },
              ),
              const SizedBox(height: 8),
              Text(
                isPremium ? 'Reminder schedule' : 'Reminder schedule (Starter fixed)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              if (!isPremium)
                const Text('Starter uses: 7 days, 1 day, and due day.')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _advancedOffsets.map((offset) {
                    final selected = prefs.offsetDays.contains(offset);
                    final label = offset == 0 ? 'Due day' : '$offset day${offset > 1 ? 's' : ''}';
                    return FilterChip(
                      label: Text(label),
                      selected: selected,
                      onSelected: (on) async {
                        final set = {...prefs.offsetDays};
                        if (on) {
                          set.add(offset);
                        } else {
                          set.remove(offset);
                        }
                        if (set.isEmpty) return;
                        await ref.read(orderReminderPreferencesProvider.notifier).setOffsets(set.toList());
                        await reschedule();
                      },
                    );
                  }).toList(),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
