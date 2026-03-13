import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../features/orders/domain/order_entry.dart';

const _kSnoozeActionId = 'snooze_1h';
const _kMarkSeenActionId = 'mark_seen';
const _kSnoozedIdOffset = 100000;

class OrderReminderService {
  static const _allSupportedOffsets = [14, 7, 3, 1, 0];
  static const _starterFixedOffsets = [7, 1, 0];
  static const _kReminderEnabled = 'order_reminder_enabled';
  static const _kReminderHour = 'order_reminder_hour';
  static const _kReminderMinute = 'order_reminder_minute';
  static const _kReminderOffsets = 'order_reminder_offsets';
  static const _kReminderTimes = 'order_reminder_times';
  static const _kAlarmSoundForDueToday = 'order_reminder_alarm_due_today';
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize({void Function(NotificationResponse)? onResponse}) async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: onResponse ?? _handleNotificationResponse,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    tz.initializeTimeZones();
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    _initialized = true;
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final actionId = response.actionId;
      if (actionId == _kMarkSeenActionId) {
        final id = response.id;
        if (id != null) _plugin.cancel(id);
      } else if (actionId == _kSnoozeActionId) {
        _scheduleSnoozedNotification(data);
      }
    } catch (_) {}
  }

  Future<void> _scheduleSnoozedNotification(Map<String, dynamic> data) async {
    final orderId = data['orderId'] as String?;
    final title = data['title'] as String? ?? 'Order reminder';
    final body = data['body'] as String? ?? '';
    if (orderId == null) return;
    final scheduledAt = tz.TZDateTime.now(tz.local).add(const Duration(hours: 1));
    final snoozeId = (_notificationId(orderId, data['offset'] as int? ?? 0) + _kSnoozedIdOffset) & 0x7fffffff;
    final details = _buildNotificationDetails();
    await _plugin.zonedSchedule(
      snoozeId,
      title,
      body,
      scheduledAt,
      details,
      payload: jsonEncode(data),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
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

    final useAlarmForDueToday = effectivePrefs.alarmSoundForDueToday;
    final due = order.dueDate!.toLocal();
    final times = _effectiveTimes(effectivePrefs, hasPremiumAccess);

    for (final offset in effectiveOffsets) {
      final date = DateTime(due.year, due.month, due.day).subtract(Duration(days: offset));
      final whenLabel = offset == 0 ? 'today' : '$offset day${offset > 1 ? 's' : ''}';
      final title = 'Order due $whenLabel';
      final body = '${order.title} for ${order.customerName} is due soon.';
      final payload = jsonEncode({
        'orderId': order.id,
        'orderTitle': order.title,
        'customerName': order.customerName,
        'offset': offset,
        'title': title,
        'body': body,
      });

      final isDueToday = offset == 0;
      final details = _buildNotificationDetails(
        useAlarmSound: useAlarmForDueToday && isDueToday,
      );

      for (var ti = 0; ti < times.length; ti++) {
        final t = times[ti];
        final scheduledAt = tz.TZDateTime.from(
          DateTime(date.year, date.month, date.day, t.hour, t.minute),
          tz.local,
        );
        if (scheduledAt.isBefore(tz.TZDateTime.now(tz.local))) continue;

        final id = (_notificationId(order.id, offset) + ti * 100) & 0x7fffffff;
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          scheduledAt,
          details,
          payload: payload,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    }
  }

  List<({int hour, int minute})> _effectiveTimes(OrderReminderPrefs prefs, bool hasPremiumAccess) {
    if (hasPremiumAccess && prefs.reminderTimes.isNotEmpty) {
      return prefs.reminderTimes.map((t) => (hour: t.hour, minute: t.minute)).toList();
    }
    return [(hour: prefs.hour, minute: prefs.minute)];
  }

  NotificationDetails _buildNotificationDetails({bool useAlarmSound = false}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        useAlarmSound ? 'order_due_today_alarm' : 'order_due_reminders',
        useAlarmSound ? 'Due Today (Alarm)' : 'Order Due Reminders',
        channelDescription: useAlarmSound
            ? 'Urgent reminders for orders due today'
            : 'Reminders for order due dates',
        importance: useAlarmSound ? Importance.max : Importance.high,
        priority: useAlarmSound ? Priority.max : Priority.high,
        playSound: true,
        enableVibration: true,
        fullScreenIntent: useAlarmSound,
        category: useAlarmSound ? AndroidNotificationCategory.alarm : AndroidNotificationCategory.reminder,
        audioAttributesUsage: useAlarmSound ? AudioAttributesUsage.alarm : AudioAttributesUsage.notification,
        actions: [
          const AndroidNotificationAction(
            _kSnoozeActionId,
            'Snooze 1h',
            showsUserInterface: false,
            cancelNotification: false,
          ),
          const AndroidNotificationAction(
            _kMarkSeenActionId,
            'Mark as seen',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
      ),
    );
  }

  Future<void> cancelForOrder(String orderId) async {
    await initialize();
    for (final offset in _allSupportedOffsets) {
      final base = _notificationId(orderId, offset);
      await _plugin.cancel(base);
      for (var t = 1; t <= 10; t++) {
        await _plugin.cancel((base + t * 100) & 0x7fffffff);
      }
      await _plugin.cancel((base + _kSnoozedIdOffset) & 0x7fffffff);
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

    final timesRaw = prefs.getStringList(_kReminderTimes) ?? [];
    final reminderTimes = <({int hour, int minute})>[];
    for (final s in timesRaw) {
      final parts = s.split(':');
      if (parts.length != 2) continue;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null && h >= 0 && h <= 23 && m >= 0 && m <= 59) {
        reminderTimes.add((hour: h, minute: m));
      }
    }

    final alarmSoundForDueToday = prefs.getBool(_kAlarmSoundForDueToday) ?? false;

    return OrderReminderPrefs(
      enabled: enabled,
      hour: hour,
      minute: minute,
      offsetDays: normalized.isEmpty ? [7, 1, 0] : normalized,
      reminderTimes: reminderTimes,
      alarmSoundForDueToday: alarmSoundForDueToday,
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
    this.reminderTimes = const [],
    this.alarmSoundForDueToday = false,
  });

  final bool enabled;
  final int hour;
  final int minute;
  final List<int> offsetDays;
  final List<({int hour, int minute})> reminderTimes;
  final bool alarmSoundForDueToday;
}

final orderReminderServiceProvider = Provider<OrderReminderService>((ref) {
  return OrderReminderService();
});
