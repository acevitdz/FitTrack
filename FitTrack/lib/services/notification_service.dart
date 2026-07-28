import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/health_models.dart';

Map<String, dynamic>? decodeFitTrackNotificationPayload(String payload) {
  try {
    final decoded = jsonDecode(payload);
    if (decoded is! Map) return null;
    final value = Map<String, dynamic>.from(decoded);
    final type = value['type'];
    if (type == 'today' &&
        value['occurrenceId'] is String &&
        (value['occurrenceId'] as String).isNotEmpty) {
      return value;
    }
    if (type == 'active' &&
        value['sessionId'] is String &&
        value['phaseId'] is String &&
        value['restEndsAt'] is int) {
      return value;
    }
  } on FormatException {
    // Fall through to the only unambiguous legacy payload.
  }
  if (payload.startsWith('today:') && payload.length > 'today:'.length) {
    return {
      'type': 'today',
      'occurrenceId': payload.substring('today:'.length),
    };
  }
  return null;
}

class NotificationService {
  static const _settingsChannel = MethodChannel('fittrack/settings');
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _messagingInitialized = false;
  bool Function() _pushEnabled = () => false;
  ValueChanged<String>? _payloadHandler;
  String? _pendingPayload;

  void setPayloadHandler(ValueChanged<String> handler) {
    _payloadHandler = handler;
    final pending = _pendingPayload;
    if (pending != null) {
      _pendingPayload = null;
      handler(pending);
    }
  }

  Future<void> initialize() async {
    if (kIsWeb) return;
    tz_data.initializeTimeZones();
    try {
      final timeZoneName = await _settingsChannel.invokeMethod<String>(
        'getTimeZone',
      );
      if (timeZoneName != null && timeZoneName.isNotEmpty) {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      } else {
        tz.setLocalLocation(tz.UTC);
      }
    } on Object {
      tz.setLocalLocation(tz.UTC);
    }
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) _dispatchPayload(payload);
      },
    );
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final launchPayload = launchDetails?.notificationResponse?.payload;
    if (launchPayload != null && launchPayload.isNotEmpty) {
      _dispatchPayload(launchPayload);
    }
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    if (kIsWeb || !_initialized) return false;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? true;
  }

  Future<bool> openNotificationSettings() async {
    if (kIsWeb || !_initialized) return false;
    try {
      return await _settingsChannel.invokeMethod<bool>(
            'openNotificationSettings',
          ) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> initializeFirebaseMessaging({
    required bool Function() isEnabled,
  }) async {
    _pushEnabled = isEnabled;
    if (_messagingInitialized || (!_initialized && !kIsWeb)) return;
    _messagingInitialized = true;
    FirebaseMessaging.onMessage.listen((message) async {
      if (kIsWeb || !_pushEnabled()) return;
      final notification = message.notification;
      if (notification == null) return;
      await _plugin.show(
        id: _stableId(
          message.messageId ??
              'push:${message.sentTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch}',
        ),
        title: notification.title ?? 'FitTrack',
        body: notification.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'fittrack_updates',
            'Cập nhật FitTrack',
            channelDescription: 'Thành tích và thông báo từ FitTrack',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: message.data['payload'] as String?,
      );
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (!_pushEnabled()) return;
      final payload = message.data['payload'] as String?;
      if (payload != null && payload.isNotEmpty) _dispatchPayload(payload);
    });
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    final initialPayload = initialMessage?.data['payload'] as String?;
    if (_pushEnabled() && initialPayload != null && initialPayload.isNotEmpty) {
      _dispatchPayload(initialPayload);
    }
  }

  Future<void> schedule(WorkoutReminder reminder) async {
    if (kIsWeb || !_initialized) return;
    await cancel(reminder.id);
    if (!reminder.enabled) return;
    if (reminder.type == ReminderType.once) {
      final date = reminder.scheduledDate;
      if (date == null) return;
      final target = tz.TZDateTime(
        tz.local,
        date.year,
        date.month,
        date.day,
        reminder.hour,
        reminder.minute,
      ).subtract(Duration(minutes: reminder.minutesBefore));
      if (!target.isAfter(tz.TZDateTime.now(tz.local))) return;
      await _plugin.zonedSchedule(
        id: _notificationId(reminder.id, 0),
        title: 'Đến giờ luyện tập!',
        body: reminder.title,
        scheduledDate: target,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'workout_reminders',
            'Lịch tập',
            channelDescription: 'Thông báo nhắc lịch luyện tập',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: reminder.planId,
      );
      return;
    }
    for (final weekday in reminder.weekdays) {
      final notificationId = _notificationId(reminder.id, weekday);
      var target = _nextWeekday(
        weekday,
        reminder.hour,
        reminder.minute,
      ).subtract(Duration(minutes: reminder.minutesBefore));
      if (!target.isAfter(tz.TZDateTime.now(tz.local))) {
        target = target.add(const Duration(days: 7));
      }
      await _plugin.zonedSchedule(
        id: notificationId,
        title: 'Đến giờ luyện tập!',
        body: reminder.title,
        scheduledDate: target,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'workout_reminders',
            'Lịch tập',
            channelDescription: 'Thông báo nhắc lịch luyện tập hằng tuần',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: reminder.planId,
      );
    }
  }

  Future<void> cancel(String reminderId) async {
    if (kIsWeb || !_initialized) return;
    for (var weekday = 0; weekday <= 7; weekday++) {
      await _plugin.cancel(id: _notificationId(reminderId, weekday));
    }
  }

  Future<void> scheduleProgramOccurrence({
    required String occurrenceId,
    required String title,
    required DateTime scheduledAt,
    required int minutesBefore,
  }) async {
    if (kIsWeb || !_initialized) return;
    final target = tz.TZDateTime.from(
      scheduledAt.subtract(Duration(minutes: minutesBefore)),
      tz.local,
    );
    if (!target.isAfter(tz.TZDateTime.now(tz.local))) return;
    final id = _stableId('occurrence:$occurrenceId');
    await _plugin.cancel(id: id);
    await _plugin.zonedSchedule(
      id: id,
      title: 'Buổi tập sắp bắt đầu',
      body: title,
      scheduledDate: target,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'program_schedule',
          'Lịch chương trình',
          channelDescription: 'Nhắc các buổi sinh từ chương trình đang theo',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: jsonEncode({'type': 'today', 'occurrenceId': occurrenceId}),
    );
  }

  Future<void> scheduleRestEnd({
    required String sessionId,
    required String phaseId,
    required DateTime restEndsAt,
  }) async {
    if (kIsWeb || !_initialized) return;
    final target = tz.TZDateTime.from(restEndsAt, tz.local);
    if (!target.isAfter(tz.TZDateTime.now(tz.local))) return;
    final identity =
        'rest:$sessionId:$phaseId:${restEndsAt.millisecondsSinceEpoch}';
    final id = _stableId(identity);
    await _plugin.zonedSchedule(
      id: id,
      title: 'Đã hết thời gian nghỉ',
      body: 'Quay lại FitTrack để bắt đầu set tiếp theo.',
      scheduledDate: target,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'workout_rest',
          'Thời gian nghỉ',
          channelDescription: 'Thông báo khi kết thúc thời gian nghỉ giữa set',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: jsonEncode({
        'type': 'active',
        'sessionId': sessionId,
        'phaseId': phaseId,
        'restEndsAt': restEndsAt.millisecondsSinceEpoch,
      }),
    );
  }

  Future<void> cancelRest({
    required String sessionId,
    required String phaseId,
  }) async {
    if (kIsWeb || !_initialized) return;
    final pending = await _plugin.pendingNotificationRequests();
    for (final notification in pending) {
      final route = notification.payload == null
          ? null
          : decodeFitTrackNotificationPayload(notification.payload!);
      if (route?['type'] == 'active' &&
          route?['sessionId'] == sessionId &&
          route?['phaseId'] == phaseId) {
        await _plugin.cancel(id: notification.id);
      }
    }
  }

  Future<void> cancelRestSession(String sessionId) async {
    if (kIsWeb || !_initialized) return;
    final pending = await _plugin.pendingNotificationRequests();
    for (final notification in pending) {
      final route = notification.payload == null
          ? null
          : decodeFitTrackNotificationPayload(notification.payload!);
      if (route?['type'] == 'active' && route?['sessionId'] == sessionId) {
        await _plugin.cancel(id: notification.id);
      }
    }
  }

  Future<void> cancelProgramOccurrence(String occurrenceId) async {
    if (kIsWeb || !_initialized) return;
    await _plugin.cancel(id: _stableId('occurrence:$occurrenceId'));
  }

  Future<void> cancelAll() async {
    if (kIsWeb || !_initialized) return;
    await _plugin.cancelAll();
  }

  int _notificationId(String id, int weekday) => _stableId('$id:$weekday');

  int _stableId(String identity) {
    var hash = 0x811c9dc5;
    for (final unit in identity.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }

  void _dispatchPayload(String payload) {
    final handler = _payloadHandler;
    if (handler == null) {
      _pendingPayload = payload;
    } else {
      handler(payload);
    }
  }

  tz.TZDateTime _nextWeekday(int weekday, int hour, int minute) {
    var date = tz.TZDateTime.now(tz.local);
    date = tz.TZDateTime(
      tz.local,
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );
    while (date.weekday != weekday ||
        !date.isAfter(tz.TZDateTime.now(tz.local))) {
      date = date.add(const Duration(days: 1));
    }
    return date;
  }
}
