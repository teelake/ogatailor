import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kReminderEnabled = 'order_reminder_enabled';
const _kReminderHour = 'order_reminder_hour';
const _kReminderMinute = 'order_reminder_minute';
const _kReminderOffsets = 'order_reminder_offsets';

class OrderReminderPreferences {
  const OrderReminderPreferences({
    required this.enabled,
    required this.hour,
    required this.minute,
    required this.offsetDays,
  });

  final bool enabled;
  final int hour;
  final int minute;
  final List<int> offsetDays;

  static const defaults = OrderReminderPreferences(
    enabled: true,
    hour: 9,
    minute: 0,
    offsetDays: [7, 1, 0],
  );

  OrderReminderPreferences copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    List<int>? offsetDays,
  }) {
    return OrderReminderPreferences(
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      offsetDays: offsetDays ?? this.offsetDays,
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

    state = OrderReminderPreferences(
      enabled: enabled,
      hour: hour,
      minute: minute,
      offsetDays: offsets.isEmpty ? [7, 1, 0] : offsets,
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
}

final orderReminderPreferencesProvider =
    StateNotifierProvider<OrderReminderPreferencesNotifier, OrderReminderPreferences>((ref) {
  return OrderReminderPreferencesNotifier();
});
