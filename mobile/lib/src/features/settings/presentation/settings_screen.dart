import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/change_password_screen.dart';
import '../../auth/presentation/edit_profile_screen.dart';
import '../../invoice/presentation/invoice_setup_screen.dart';
import '../../orders/application/orders_controller.dart';
import '../../plan/application/plan_controller.dart';
import '../../plan/presentation/upgrade_screen.dart';
import '../../reports/presentation/export_reports_screen.dart';
import '../../../core/network/api_client.dart';
import '../../../core/preferences/measurement_unit_provider.dart';
import '../../../core/preferences/order_reminder_preferences_provider.dart';
import '../../../core/preferences/theme_mode_provider.dart';
import '../../../core/theme/app_colors.dart';

const _kSettingsCardMargin = EdgeInsets.symmetric(horizontal: 16, vertical: 4);
const _kSettingsCardPadding = EdgeInsets.all(16);

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
                icon: Icons.receipt_long_rounded,
                title: 'Invoice Setup',
                subtitle: 'Business details for generating invoices',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const InvoiceSetupScreen()),
                ),
              ),
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
              _ThemeModeTile(),
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
                subtitle: 'Generate measurement summaries and CSV reports',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ExportReportsScreen()),
                ),
              ),
            ],
          ),
          _SettingsSection(
            title: 'Danger Zone',
            children: [
              _SettingsTile(
                icon: Icons.logout_rounded,
                title: 'Log out',
                subtitle: 'Sign out from this device',
                destructive: true,
                onTap: () => _confirmLogout(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Changes are saved automatically.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 20),
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
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    this.destructive = false,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool destructive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = destructive ? Theme.of(context).colorScheme.error : AppColors.primary;
    final titleColor = destructive ? Theme.of(context).colorScheme.error : null;

    return Card(
      margin: _kSettingsCardMargin,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minLeadingWidth: 24,
        titleAlignment: ListTileTitleAlignment.titleHeight,
        leading: Icon(icon, color: iconColor),
        title: Text(
          title,
          style: titleColor == null ? null : TextStyle(color: titleColor, fontWeight: FontWeight.w600),
        ),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing: trailing ?? const Icon(Icons.chevron_right_rounded, size: 20),
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
      margin: _kSettingsCardMargin,
      child: Padding(
        padding: _kSettingsCardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardSectionHeader(
              icon: Icons.straighten_rounded,
              title: 'Measurement unit',
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

class _ThemeModeTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Card(
      margin: _kSettingsCardMargin,
      child: Padding(
        padding: _kSettingsCardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardSectionHeader(
              icon: Icons.palette_rounded,
              title: 'Appearance',
              subtitle: 'Choose how Oga Tailor looks on this device',
            ),
            const SizedBox(height: 12),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text(
                    'System',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text(
                    'Light',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text(
                    'Dark',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              showSelectedIcon: false,
              selected: {themeMode},
              onSelectionChanged: (selected) async {
                await ref.read(themeModeProvider.notifier).setThemeMode(selected.first);
              },
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
  final shouldLogout = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Log out?'),
      content: const Text('You will need to sign in again to access your account on this device.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Log out'),
        ),
      ],
    ),
  );

  if (shouldLogout == true) {
    await ref.read(authControllerProvider.notifier).logout();
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

class _OrderReminderTile extends ConsumerStatefulWidget {
  @override
  ConsumerState<_OrderReminderTile> createState() => _OrderReminderTileState();
}

class _OrderReminderTileState extends ConsumerState<_OrderReminderTile> {
  bool _showAdvancedReminders = false;
  static const _advancedOffsets = [14, 7, 3, 1, 0];

  @override
  Widget build(BuildContext context) {
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
      margin: _kSettingsCardMargin,
      child: Padding(
        padding: _kSettingsCardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: _CardSectionHeader(
                    icon: Icons.notifications_active_rounded,
                    title: 'Order due reminders',
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
              const SizedBox(height: 4),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Alarm sound for due today'),
                subtitle: const Text('Louder notification when order is due today'),
                value: prefs.alarmSoundForDueToday,
                onChanged: (v) async {
                  await ref.read(orderReminderPreferencesProvider.notifier).setAlarmSoundForDueToday(v);
                  await reschedule();
                },
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => setState(() => _showAdvancedReminders = !_showAdvancedReminders),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        _showAdvancedReminders ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _showAdvancedReminders ? 'Hide schedule options' : 'Schedule & more options',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_showAdvancedReminders) ...[
                const SizedBox(height: 12),
                Text(
                  isPremium ? 'When to remind' : 'Reminder schedule (Starter fixed)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                if (!isPremium)
                  const Text('Starter: 7 days, 1 day, and due day before.')
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
              if (isPremium) ...[
                const SizedBox(height: 16),
                Text(
                  'Multiple times per day',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Get reminders at each time (e.g. 9:00 and 18:00)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...prefs.reminderTimes.map((t) => Chip(
                      label: Text(t.label),
                      onDeleted: () async {
                        final updated = prefs.reminderTimes.where((x) => x.hour != t.hour || x.minute != t.minute).toList();
                        await ref.read(orderReminderPreferencesProvider.notifier).setReminderTimes(updated);
                        await reschedule();
                      },
                    )),
                    if (prefs.reminderTimes.length < 3)
                      ActionChip(
                        label: const Text('+ Add time'),
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(hour: prefs.hour, minute: prefs.minute),
                          );
                          if (picked != null) {
                            final updated = [...prefs.reminderTimes, ReminderTime(picked.hour, picked.minute)];
                            await ref.read(orderReminderPreferencesProvider.notifier).setReminderTimes(updated);
                            await reschedule();
                          }
                        },
                      ),
                  ],
                ),
                if (prefs.reminderTimes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Use single time above, or add more times',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Daily email digest'),
                  subtitle: const Text('Summary of upcoming orders by email'),
                  value: prefs.emailDigestEnabled,
                  onChanged: (v) async {
                    await ref.read(orderReminderPreferencesProvider.notifier).setEmailDigestEnabled(v);
                    try {
                      if (v) {
                        await ref.read(dioProvider).post('/api/reminders/daily-digest/subscribe');
                      } else {
                        await ref.read(dioProvider).post('/api/reminders/daily-digest/unsubscribe');
                      }
                    } catch (_) {}
                  },
                ),
              ],
            ],
          ],
          ],
        ),
      ),
    );
  }
}

class _CardSectionHeader extends StatelessWidget {
  const _CardSectionHeader({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
