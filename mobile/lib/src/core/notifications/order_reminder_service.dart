import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../features/orders/domain/order_entry.dart';

class OrderReminderService {
  static const _allSupportedOffsets = [14, 7, 3, 1, 0];
  static const _starterFixedOffsets = [7, 1, 0];
  static const _kReminderEnabled = 'order_reminder_enabled';
  static const _kReminderHour = 'order_reminder_hour';
  static const _kReminderMinute = 'order_reminder_minute';
  static const _kReminderOffsets = 'order_reminder_offsets';
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    tz.initializeTimeZones();
    try {
      final timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    _initialized = true;
  }

  Future<void> syncAll(
    List<OrderEntry> orders, {
    required bool hasPremiumAccess,
  }) async {
    await initialize();
    final prefs = await _readPreferences();

    if (!prefs.enabled) {
      for (final order in orders) {
        await cancelForOrder(order.id);
      }
      return;
    }

    for (final order in orders) {
      await scheduleForOrder(
        order,
        prefs: prefs,
        hasPremiumAccess: hasPremiumAccess,
      );
    }
  }

  Future<void> scheduleForOrder(
    OrderEntry order, {
    OrderReminderPrefs? prefs,
    required bool hasPremiumAccess,
  }) async {
    await initialize();
    final effectivePrefs = prefs ?? await _readPreferences();
    final effectiveOffsets =
        hasPremiumAccess ? effectivePrefs.offsetDays : _starterFixedOffsets;
    await cancelForOrder(order.id);

    if (!effectivePrefs.enabled) return;
    if (order.dueDate == null) return;
    if (order.status == 'delivered' || order.status == 'cancelled') return;

    final details = const NotificationDetails(
      android: AndroidNotificationDetails(
        'order_due_reminders',
        'Order Due Reminders',
        channelDescription: 'Reminders for order due dates',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    final due = order.dueDate!.toLocal();
    for (final offset in effectiveOffsets) {
      final date = DateTime(due.year, due.month, due.day).subtract(Duration(days: offset));
      final scheduledAt = tz.TZDateTime.from(
        DateTime(date.year, date.month, date.day, effectivePrefs.hour, effectivePrefs.minute),
        tz.local,
      );
      if (scheduledAt.isBefore(tz.TZDateTime.now(tz.local))) {
        continue;
      }

      final id = _notificationId(order.id, offset);
      final whenLabel = offset == 0 ? 'today' : '$offset day${offset > 1 ? 's' : ''}';
      await _plugin.zonedSchedule(
        id,
        'Order due $whenLabel',
        '${order.title} for ${order.customerName} is due soon.',
        scheduledAt,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> cancelForOrder(String orderId) async {
    await initialize();
    for (final offset in _allSupportedOffsets) {
      await _plugin.cancel(_notificationId(orderId, offset));
    }
  }

  Future<OrderReminderPrefs> _readPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_kReminderEnabled) ?? true;
    final hour = prefs.getInt(_kReminderHour) ?? 9;
    final minute = prefs.getInt(_kReminderMinute) ?? 0;
    final offsets = prefs
            .getStringList(_kReminderOffsets)
            ?.map((e) => int.tryParse(e))
            .whereType<int>()
            .toList() ??
        [7, 1, 0];

    final normalized = offsets.toSet().where(_allSupportedOffsets.contains).toList()
      ..sort((a, b) => b.compareTo(a));

    return OrderReminderPrefs(
      enabled: enabled,
      hour: hour,
      minute: minute,
      offsetDays: normalized.isEmpty ? [7, 1, 0] : normalized,
    );
  }

  int _notificationId(String orderId, int offset) {
    final base = orderId.hashCode & 0x7fffffff;
    return (base + offset) & 0x7fffffff;
  }
}

class OrderReminderPrefs {
  const OrderReminderPrefs({
    required this.enabled,
    required this.hour,
    required this.minute,
    required this.offsetDays,
  });

  final bool enabled;
  final int hour;
  final int minute;
  final List<int> offsetDays;
}

final orderReminderServiceProvider = Provider<OrderReminderService>((ref) {
  return OrderReminderService();
});
