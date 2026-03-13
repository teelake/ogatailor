import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kReminderEnabled = 'order_reminder_enabled';
const _kReminderHour = 'order_reminder_hour';
const _kReminderMinute = 'order_reminder_minute';
const _kReminderOffsets = 'order_reminder_offsets';
const _kReminderTimes = 'order_reminder_times';
const _kEmailDigestEnabled = 'order_reminder_email_digest_enabled';
const _kAlarmSoundForDueToday = 'order_reminder_alarm_due_today';

/// A single reminder time (hour, minute).
class ReminderTime {
  const ReminderTime(this.hour, this.minute);
  final int hour;
  final int minute;
  String get label => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

class OrderReminderPreferences {
  const OrderReminderPreferences({
    required this.enabled,
    required this.hour,
    required this.minute,
    required this.offsetDays,
    required this.reminderTimes,
    required this.emailDigestEnabled,
  });

  final bool enabled;
  final int hour;
  final int minute;
  final List<int> offsetDays;
  /// Multiple times per day (Growth/Pro). Empty = use single (hour, minute).
  final List<ReminderTime> reminderTimes;
  final bool emailDigestEnabled;
  /// Use alarm-like sound for "due today" reminders.
  final bool alarmSoundForDueToday;

  static const defaults = OrderReminderPreferences(
    enabled: true,
    hour: 9,
    minute: 0,
    offsetDays: [7, 1, 0],
    reminderTimes: [],
    emailDigestEnabled: false,
    alarmSoundForDueToday: false,
  );

  OrderReminderPreferences copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    List<int>? offsetDays,
    List<ReminderTime>? reminderTimes,
    bool? emailDigestEnabled,
    bool? alarmSoundForDueToday,
  }) {
    return OrderReminderPreferences(
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      offsetDays: offsetDays ?? this.offsetDays,
      reminderTimes: reminderTimes ?? this.reminderTimes,
      emailDigestEnabled: emailDigestEnabled ?? this.emailDigestEnabled,
      alarmSoundForDueToday: alarmSoundForDueToday ?? this.alarmSoundForDueToday,
    );
  }
}

class OrderReminderPreferencesNotifier extends StateNotifier<OrderReminderPreferences> {
  OrderReminderPreferencesNotifier() : super(OrderReminderPreferences.defaults) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_kReminderEnabled) ?? true;
    final hour = prefs.getInt(_kReminderHour) ?? 9;
    final minute = prefs.getInt(_kReminderMinute) ?? 0;
    final offsets = prefs
            .getStringList(_kReminderOffsets)
            ?.map((e) => int.tryParse(e))
            .whereType<int>()
            .toSet()
            .toList() ??
        [7, 1, 0];
    offsets.sort((a, b) => b.compareTo(a));

    final timesRaw = prefs.getStringList(_kReminderTimes) ?? [];
    final reminderTimes = timesRaw
        .map((s) {
          final parts = s.split(':');
          if (parts.length != 2) return null;
          final h = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return null;
          return ReminderTime(h, m);
        })
        .whereType<ReminderTime>()
        .toList();

    final emailDigestEnabled = prefs.getBool(_kEmailDigestEnabled) ?? false;
    final alarmSoundForDueToday = prefs.getBool(_kAlarmSoundForDueToday) ?? false;

    state = OrderReminderPreferences(
      enabled: enabled,
      hour: hour,
      minute: minute,
      offsetDays: offsets.isEmpty ? [7, 1, 0] : offsets,
      reminderTimes: reminderTimes,
      emailDigestEnabled: emailDigestEnabled,
      alarmSoundForDueToday: alarmSoundForDueToday,
    );
  }

  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(enabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kReminderEnabled, enabled);
  }

  Future<void> setTime(int hour, int minute) async {
    state = state.copyWith(hour: hour, minute: minute);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kReminderHour, hour);
    await prefs.setInt(_kReminderMinute, minute);
  }

  Future<void> setOffsets(List<int> offsets) async {
    final normalized = offsets.toSet().toList()..sort((a, b) => b.compareTo(a));
    state = state.copyWith(offsetDays: normalized);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kReminderOffsets, normalized.map((e) => e.toString()).toList());
  }

  Future<void> setReminderTimes(List<ReminderTime> times) async {
    state = state.copyWith(reminderTimes: times);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kReminderTimes, times.map((t) => '${t.hour}:${t.minute}').toList());
  }

  Future<void> setEmailDigestEnabled(bool enabled) async {
    state = state.copyWith(emailDigestEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEmailDigestEnabled, enabled);
  }

  Future<void> setAlarmSoundForDueToday(bool enabled) async {
    state = state.copyWith(alarmSoundForDueToday: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAlarmSoundForDueToday, enabled);
  }
}

final orderReminderPreferencesProvider =
    StateNotifierProvider<OrderReminderPreferencesNotifier, OrderReminderPreferences>((ref) {
  return OrderReminderPreferencesNotifier();
});
